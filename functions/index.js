const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onDocumentCreated, onDocumentUpdated, onDocumentDeleted} = require('firebase-functions/v2/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const nodemailer = require('nodemailer');
const crypto = require('crypto');

initializeApp();
const db = getFirestore();

// 신고 접수 메일을 보낼 관리자(운영자) 주소입니다. 발신 계정도 같은 Gmail
// 주소를 사용하며, 실제 비밀번호가 아니라 앱 비밀번호(App Password)를 Secret
// Manager에 GMAIL_APP_PASSWORD라는 이름으로 등록해서 씁니다.
// 등록 방법: firebase functions:secrets:set GMAIL_APP_PASSWORD
const ADMIN_EMAIL = 'micket0012@gmail.com';
const gmailAppPassword = defineSecret('GMAIL_APP_PASSWORD');

// AI 추천가(웹 시세 검색)용 외부 API 키들은 '환경변수'로 읽어요.
// 이렇게 하면 키가 아직 없어도 배포가 막히지 않고(그 소스만 건너뜀), 나중에
// 키가 생기면 아래 둘 중 하나로 넣고 재배포하면 바로 켜져요:
//   (A) 간단 — functions/.env 파일에 적기 (.gitignore로 커밋 제외됨):
//         OPENAI_API_KEY=sk-...
//         NAVER_CLIENT_ID=...
//         NAVER_CLIENT_SECRET=...
//   (B) 더 안전(운영 권장) — Secret Manager에 넣고 recommendPrice 옵션에
//         secrets:[...]로 다시 선언해서 .value()로 읽기. 단, 이 경우 키가 반드시
//         존재해야 배포돼요(지금 배포가 막혔던 원인). 값 없이 엔터 금지!
// 세 키 중 없는 것은 그 소스만 건너뛰고, 있는 소스만으로 추천가를 계산해요.
// (셋 다 없으면 웹 시세는 비고, 앱 내부 데이터/규칙 폴백만 동작 — 그래도 배포는 정상)

/** 신고 관련 메일을 관리자에게 보냅니다. 메일 전송이 실패해도(예: 앱 비밀번호
 *  미설정) 신고 접수 자체가 실패한 것처럼 보이면 안 되므로 예외를 삼킵니다. */
async function sendAdminReportEmail(subject, lines) {
  try {
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {user: ADMIN_EMAIL, pass: gmailAppPassword.value()},
    });
    await transporter.sendMail({
      from: `"덕옥션 신고 알림" <${ADMIN_EMAIL}>`,
      to: ADMIN_EMAIL,
      subject,
      text: lines.filter(Boolean).join('\n'),
    });
  } catch (e) {
    console.error('[report-email] 전송 실패', e);
  }
}

// 결제 시나리오 관리 화면(runPaymentTestScenario, home_screen.dart)과 동일한
// 규칙을 씁니다: 1순위 24시간, 2·3순위 각 12시간.
const FIRST_DEADLINE_HOURS = 24;
const NEXT_DEADLINE_HOURS = 12;
const RANK_STATUS = ['winner_pending', 'second_pending', 'third_pending'];

// 안티-스나이핑(소프트 클로즈): 마감 이 시간 이내에 입찰이 들어오면 마감을
// '지금부터 이만큼 뒤'로 자동 연장해요. (막판 낚아채기 방지)
const ANTI_SNIPE_WINDOW_MS = 5 * 60 * 1000;

/**
 * 5분마다 실행되어 두 가지 일을 처리합니다.
 *
 * 1) 마감 시각(endAt)이 지났는데도 'active'로 남아있는 경매를 마감 처리
 *    (입찰이 있었으면 1순위 결제대기, 없었으면 유찰)
 * 2) 결제 기한(paymentDeadlineAt)이 지났는데도 결제되지 않은 낙찰 건을
 *    다음 순위 입찰자에게 자동으로 넘기고(2·3순위), 3순위까지도 넘길
 *    사람이 없으면 유찰 처리
 *
 * 유찰(failed) 이후 판매자에게 "재경매/새로 등록"을 안내하는 건 이미
 * 앱의 "내 경매 관리" 화면이 effectiveStatus == 'failed' 조건으로 자동
 * 처리하고 있어서, 여기서는 상태 전환까지만 책임집니다. 상태가 바뀔 때마다
 * sendPushToUser()로 관련자에게 푸시 알림도 함께 보냅니다.
 *
 * 주의: 아래 두 쿼리는 각각 복합 색인이 필요합니다.
 * - status == 'active' && endAt <= now → (status, endAt)
 * - status in [...] && paymentDeadlineAt <= now → (status, paymentDeadlineAt)
 * firestore.indexes.json에 미리 정의해뒀습니다.
 */
exports.closeExpiredAuctions = onSchedule('every 5 minutes', async (event) => {
  const now = Timestamp.now();

  const expiredAuctions = await db
    .collection('products')
    .where('status', '==', 'active')
    .where('endAt', '<=', now)
    .get();

  if (!expiredAuctions.empty) {
    console.log(`${expiredAuctions.size}개의 경매를 마감 처리합니다.`);
    const results = await Promise.allSettled(
      expiredAuctions.docs.map((doc) => closeOneAuction(doc.ref)),
    );
    logFailures('마감 처리', results);
  } else {
    console.log('마감할 경매가 없습니다.');
  }

  // 결제 기한이 지난 순위별(1/2/3순위) 건을 각각 조회합니다. status에
  // 'in' 조건을 쓰면 다른 필드의 범위 조건과 함께 별도 색인이 더 필요해질
  // 수 있어, 위에서 정의한 단일 색인(status, paymentDeadlineAt)만으로
  // 동작하도록 순위별로 나눠서 조회합니다.
  for (const status of RANK_STATUS) {
    const overdue = await db
      .collection('products')
      .where('status', '==', status)
      .where('paymentDeadlineAt', '<=', now)
      .get();

    if (overdue.empty) continue;

    console.log(`'${status}' 결제 기한 초과 ${overdue.size}건을 처리합니다.`);
    const results = await Promise.allSettled(
      overdue.docs.map((doc) => escalateOneAuction(doc.ref, status)),
    );
    logFailures(`${status} 에스컬레이션`, results);
  }
});

function logFailures(label, settledResults) {
  const failed = settledResults.filter((r) => r.status === 'rejected');
  if (failed.length > 0) {
    console.error(`[${label}] ${failed.length}건 실패`, failed.map((r) => r.reason));
  }
}

async function closeOneAuction(productRef) {
  // 트랜잭션 안에서는 외부 API(FCM 전송) 호출을 하지 않고, 무엇을 보내야
  // 하는지만 outcome으로 정리해서 돌려준 뒤 트랜잭션이 끝나고 나서 보냅니다
  // (트랜잭션은 충돌 시 재시도될 수 있어 그 안에서 알림을 보내면 중복 발송될
  // 수 있어요).
  const outcome = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(productRef);
    if (!snap.exists) return null;
    const data = snap.data();

    // 트랜잭션 안에서 다시 한 번 확인해서, 그 사이 다른 곳에서 이미
    // 상태가 바뀌었다면 건너뜁니다(중복 처리 방지).
    if (data.status !== 'active') return null;

    const endAt = data.endAt;
    if (!endAt || endAt.toMillis() > Date.now()) return null;

    const title = data.title || '상품';
    const sellerId = data.sellerId || null;

    // 입찰 기록에서 사용자별 최고 입찰가를 기준으로 낙찰 순번(1~3순위)
    // 큐를 만듭니다. 같은 사람이 여러 번 입찰했어도 한 번만 포함됩니다.
    const bidsSnap = await transaction.get(
      productRef.collection('bids').orderBy('amount', 'desc').orderBy('createdAt', 'asc'),
    );
    const queue = buildBidderQueue(bidsSnap.docs);

    if (queue.length === 0) {
      transaction.update(productRef, {
        status: 'failed',
        paymentRank: null,
        paymentDeadlineAt: null,
        closedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {type: 'failed_no_bids', productId: productRef.id, title, sellerId};
    }

    const winner = queue[0];
    transaction.update(productRef, {
      status: 'winner_pending',
      paymentRank: 1,
      paymentDeadlineAt: addHours(now(), FIRST_DEADLINE_HOURS),
      bidderQueue: queue,
      lastBidUserId: winner.userId,
      lastBidUserName: winner.userName,
      lastBidAmount: winner.amount,
      winnerId: winner.userId,
      buyerId: winner.userId,
      closedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {type: 'won', productId: productRef.id, title, sellerId, winnerId: winner.userId};
  });

  if (!outcome) return;

  if (outcome.type === 'won') {
    await Promise.allSettled([
      sendPushToUser(outcome.winnerId, {
        title: '낙찰되었어요!',
        body: `"${outcome.title}" 경매에 낙찰됐어요. 24시간 안에 결제를 완료해주세요.`,
        data: {type: 'auction_won', productId: outcome.productId},
      }),
      outcome.sellerId
        ? sendPushToUser(outcome.sellerId, {
            title: '경매가 마감됐어요',
            body: `"${outcome.title}" 경매가 마감되고 낙찰자가 정해졌어요.`,
            data: {type: 'auction_closed', productId: outcome.productId},
          })
        : Promise.resolve(),
    ]);
  } else if (outcome.type === 'failed_no_bids' && outcome.sellerId) {
    await sendPushToUser(outcome.sellerId, {
      title: '경매가 유찰됐어요',
      body: `"${outcome.title}" 경매에 입찰자가 없어 유찰됐어요. 다시 등록해보세요.`,
      data: {type: 'auction_failed', productId: outcome.productId},
    });
  }
}

async function escalateOneAuction(productRef, expectedStatus) {
  const outcome = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(productRef);
    if (!snap.exists) return null;
    const data = snap.data();

    // 그 사이 결제가 완료됐거나 다른 곳에서 이미 처리됐다면 건너뜁니다.
    if (data.status !== expectedStatus) return null;

    const deadline = data.paymentDeadlineAt;
    if (!deadline || deadline.toMillis() > Date.now()) return null;

    const currentRankIndex = RANK_STATUS.indexOf(expectedStatus);
    const nextRankIndex = currentRankIndex + 1;
    const queue = Array.isArray(data.bidderQueue) ? data.bidderQueue : [];
    const title = data.title || '상품';
    const sellerId = data.sellerId || null;

    const warningUpdate = {
      paymentWarningCount: FieldValue.increment(1),
      lastPaymentWarningAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (nextRankIndex < RANK_STATUS.length && nextRankIndex < queue.length) {
      const nextBidder = queue[nextRankIndex];
      transaction.update(productRef, {
        ...warningUpdate,
        status: RANK_STATUS[nextRankIndex],
        paymentRank: nextRankIndex + 1,
        paymentDeadlineAt: addHours(now(), NEXT_DEADLINE_HOURS),
        lastBidUserId: nextBidder.userId,
        lastBidUserName: nextBidder.userName,
        lastBidAmount: nextBidder.amount,
        winnerId: nextBidder.userId,
        buyerId: nextBidder.userId,
      });
      return {type: 'escalated', productId: productRef.id, title, sellerId, nextUserId: nextBidder.userId};
    }

    // 더 이상 넘길 차순위 입찰자가 없으면(3순위까지 소진) 유찰 처리합니다.
    // 판매자는 "내 경매 관리" 화면에서 유찰된 경매에 자동으로 뜨는
    // "경매 연장"/"새로 등록" 버튼으로 재경매하거나, 아무 것도 하지 않는
    // 방식으로 거래를 취소할 수 있습니다.
    transaction.update(productRef, {
      ...warningUpdate,
      status: 'failed',
      paymentRank: null,
      paymentDeadlineAt: null,
    });
    return {type: 'failed_payment_timeout', productId: productRef.id, title, sellerId};
  });

  if (!outcome) return;

  if (outcome.type === 'escalated') {
    await sendPushToUser(outcome.nextUserId, {
      title: '결제 순번이 넘어왔어요',
      body: `"${outcome.title}" 경매의 결제 차례가 됐어요. 정해진 시간 안에 결제해주세요.`,
      data: {type: 'payment_rank_up', productId: outcome.productId},
    });
  } else if (outcome.type === 'failed_payment_timeout' && outcome.sellerId) {
    await sendPushToUser(outcome.sellerId, {
      title: '경매가 유찰됐어요',
      body: `"${outcome.title}" 결제 기한이 모두 지나서 유찰 처리됐어요.`,
      data: {type: 'auction_failed', productId: outcome.productId},
    });
  }
}

/** 입찰 기록에서 사용자별 최고 입찰가만 남겨 금액 내림차순으로 정렬합니다.
 *  이미 amount desc, createdAt asc로 정렬돼 들어오므로 같은 유저의 첫 등장이
 *  곧 그 유저의 최고 입찰가이고, 동일 금액이면 먼저 입찰한 사람이 앞에 옵니다. */
function buildBidderQueue(bidDocs) {
  const seen = new Set();
  const queue = [];
  for (const doc of bidDocs) {
    const bid = doc.data();
    const userId = bid.userId;
    if (!userId || seen.has(userId)) continue;
    seen.add(userId);
    queue.push({
      userId,
      userName: bid.userName || '입찰자',
      amount: Number(bid.amount || 0),
    });
    if (queue.length >= 3) break;
  }
  return queue;
}

function now() {
  return new Date();
}

function addHours(date, hours) {
  return Timestamp.fromDate(new Date(date.getTime() + hours * 60 * 60 * 1000));
}

/** 특정 사용자(uid)의 등록된 기기로 푸시 알림을 보냅니다.
 *  - users/{uid}.pushEnabled가 명시적으로 false면 보내지 않습니다(기본값은 발송).
 *  - 앱을 지웠거나 만료된 기기 토큰은 전송 결과를 보고 자동으로 정리합니다.
 *  - uid가 없거나, 유저 문서/토큰이 없거나, 전송이 실패해도 호출한 쪽의 흐름을
 *    막지 않도록 예외를 밖으로 던지지 않습니다. */
async function sendPushToUser(uid, {title, body, data = {}}) {
  if (!uid) return;
  try {
    const userSnap = await db.collection('users').doc(uid).get();
    if (!userSnap.exists) return;
    const userData = userSnap.data();

    // 인앱 알림함(users/{uid}/notifications)에 항상 기록합니다. 홈 우측상단 알림
    // 아이콘을 눌렀을 때 여기에서 확인할 수 있게요. 기기 토큰 유무나 푸시 수신
    // 설정(pushEnabled)과 무관하게 저장해서, 시스템 푸시를 못 받아도 앱 안에서는
    // 알림 내역이 남게 합니다.
    try {
      await db.collection('users').doc(uid).collection('notifications').add({
        title: title || '',
        body: body || '',
        data: data || {},
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (e2) {
      console.error('[push] 알림함 저장 실패', e2);
    }

    if (userData.pushEnabled === false) return;

    const tokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens.filter(Boolean) : [];
    if (tokens.length === 0) return;

    // FCM data 필드는 문자열만 허용해서, 숫자/기타 값을 전부 문자열로 바꿔줍니다.
    const stringData = Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)]),
    );

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: stringData,
    });

    const staleTokens = [];
    response.responses.forEach((result, index) => {
      const errorCode = result.error?.code;
      if (!result.success
        && (errorCode === 'messaging/registration-token-not-registered'
          || errorCode === 'messaging/invalid-registration-token')) {
        staleTokens.push(tokens[index]);
      }
    });
    if (staleTokens.length > 0) {
      await db.collection('users').doc(uid).update({
        fcmTokens: FieldValue.arrayRemove(...staleTokens),
      });
    }
  } catch (e) {
    console.error(`[push] ${uid}에게 알림 전송 실패`, e);
  }
}

/** 상품에 새 입찰이 등록되면 판매자에게 알려주고, 이번 입찰로 직전 최고
 *  입찰자가 밀려났다면 그 사람에게도 "아웃비드" 알림을 보냅니다. */
exports.onNewBid = onDocumentCreated('products/{productId}/bids/{bidId}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const bid = snap.data();
  const productId = event.params.productId;

  const productRef = db.collection('products').doc(productId);
  const productSnap = await productRef.get();
  if (!productSnap.exists) return;
  const product = productSnap.data();
  const title = product.title || '상품';

  // ── 안티-스나이핑(소프트 클로즈) ──
  // 마감 5분 이내에 '현재가를 올린' 입찰이 들어오면 마감을 '지금부터 5분 뒤'로
  // 연장해요. 트랜잭션 안에서 상태(active)·마감 시각을 다시 확인해서, 마감
  // 스케줄러(closeExpiredAuctions)와 동시에 실행돼도 '이미 닫힌 경매'를 잘못
  // 연장하는 경합을 막아요. 무효/저가 입찰로 무한 연장되는 것도 막아요.
  // 서버에서 강제 연장이라, 앱을 조작한 막판 스나이핑도 못 피해요.
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(productRef);
      if (!snap.exists) return;
      const p = snap.data();
      if (p.status !== 'active') return;
      const end = p.endAt;
      if (!end || typeof end.toMillis !== 'function') return;
      const nowMs = Date.now();
      const remaining = end.toMillis() - nowMs;
      if (remaining <= 0 || remaining > ANTI_SNIPE_WINDOW_MS) return;
      // 이 입찰이 현재가 이상으로 올린 유효 입찰일 때만 연장해요(무효/저가 입찰 무시).
      if (Number(bid.amount || 0) < Number(p.currentPrice || 0)) return;
      tx.update(productRef, {
        endAt: Timestamp.fromMillis(nowMs + ANTI_SNIPE_WINDOW_MS),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (e) {
    console.error('[anti-snipe] 마감 연장 실패', productId, e);
  }

  const tasks = [];

  if (product.sellerId) {
    const amountLabel = Number(bid.amount || 0).toLocaleString('ko-KR');
    tasks.push(sendPushToUser(product.sellerId, {
      title: '새 입찰이 들어왔어요',
      body: `"${title}"에 ${bid.userName || '누군가'}님이 ${amountLabel}원에 입찰했어요.`,
      data: {type: 'new_bid', productId},
    }));
  }

  // 시간순으로 바로 직전 입찰(=이번 입찰에 밀려난 사람)을 찾아 아웃비드
  // 알림을 보냅니다. 예약입찰(자동입찰)의 맞대응 기록도 같은 컬렉션에 남기
  // 때문에, 이번 입찰과 작성자가 다른 가장 최근 기록을 찾으면 됩니다.
  const recentBidsSnap = await productRef
    .collection('bids')
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();
  const previousBid = recentBidsSnap.docs
    .map((doc) => doc.data())
    .find((other) => other.userId && other.userId !== bid.userId);

  if (previousBid && previousBid.userId !== product.sellerId) {
    tasks.push(sendPushToUser(previousBid.userId, {
      title: '더 높은 입찰이 들어왔어요',
      body: `"${title}"에 나보다 높은 금액으로 입찰한 사람이 나타났어요. 다시 입찰해보세요.`,
      data: {type: 'outbid', productId},
    }));
  }

  await Promise.allSettled(tasks);
});

/** 채팅방에 새 메시지가 오면, 보낸 사람을 제외한 참여자들에게 알려줍니다. */
exports.onNewChatMessage = onDocumentCreated('chatRooms/{roomId}/messages/{messageId}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const message = snap.data();
  const roomId = event.params.roomId;
  const senderUid = message.senderUid;
  if (!senderUid) return;

  const roomSnap = await db.collection('chatRooms').doc(roomId).get();
  if (!roomSnap.exists) return;
  const room = roomSnap.data();
  const participants = Array.isArray(room.participants) ? room.participants : [];
  const recipients = participants.filter((uid) => uid && uid !== senderUid);
  if (recipients.length === 0) return;

  let senderName = '덕친';
  try {
    const senderSnap = await db.collection('users').doc(senderUid).get();
    senderName = senderSnap.data()?.nickname || senderName;
  } catch (e) {
    // 이름 조회가 실패해도 기본 이름으로 계속 진행합니다.
  }

  const preview = message.type === 'image'
    ? '사진을 보냈어요'
    : String(message.text || '').slice(0, 60);

  await Promise.allSettled(
    recipients.map((uid) => sendPushToUser(uid, {
      title: `${senderName}님의 메시지`,
      body: preview,
      data: {type: 'chat_message', roomId, productId: room.productId || ''},
    })),
  );
});

/** 'reports' 컬렉션(경매/거래 신고 + 채팅 신고가 함께 들어옵니다)에 새 문서가
 *  생기면 관리자에게 메일로 알립니다. */
exports.onNewReport = onDocumentCreated(
  {document: 'reports/{reportId}', secrets: [gmailAppPassword]},
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const report = snap.data();
    const isChatReport = report.type === 'chat';
    const typeLabel = isChatReport ? '채팅 신고' : '경매/거래 신고';

    await sendAdminReportEmail(`[덕옥션] 새 신고 접수 - ${typeLabel}`, [
      `유형: ${typeLabel}`,
      `사유: ${report.reason || '(사유 없음)'}`,
      report.detail ? `상세: ${report.detail}` : null,
      report.productTitle ? `상품: ${report.productTitle}` : null,
      report.productId ? `상품 ID: ${report.productId}` : null,
      report.chatRoomId ? `채팅방 ID: ${report.chatRoomId}` : null,
      `신고자: ${report.reporterEmail || report.reporterUid || '알 수 없음'}`,
      `신고 ID: ${event.params.reportId}`,
    ]);
  },
);

/** 'reviewReports' 컬렉션(후기 신고)에 새 문서가 생기면 관리자에게 메일로
 *  알립니다. */
exports.onNewReviewReport = onDocumentCreated(
  {document: 'reviewReports/{reportId}', secrets: [gmailAppPassword]},
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const report = snap.data();

    await sendAdminReportEmail('[덕옥션] 새 신고 접수 - 후기 신고', [
      '유형: 후기 신고',
      `사유: ${report.reason || '(사유 없음)'}`,
      report.detail ? `상세: ${report.detail}` : null,
      `신고자: ${report.reporterUid || '알 수 없음'}`,
      `신고 ID: ${event.params.reportId}`,
    ]);
  },
);

/** 'adInquiries' 컬렉션(광고 문의)에 새 문서가 생기면 관리자에게 메일로 알립니다. */
exports.onNewAdInquiry = onDocumentCreated(
  {document: 'adInquiries/{inquiryId}', secrets: [gmailAppPassword]},
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const inquiry = snap.data();

    await sendAdminReportEmail(`[덕옥션] 새 광고 문의 - ${inquiry.package || '광고'}`, [
      `광고 상품: ${inquiry.package || '(미선택)'}`,
      `상점명/담당자: ${inquiry.shopName || '(없음)'}`,
      `연락처: ${inquiry.contact || '(없음)'}`,
      inquiry.message ? `문의 내용: ${inquiry.message}` : null,
      `문의 ID: ${event.params.inquiryId}`,
    ]);
  },
);

// 낙찰이 확정된 이후(결제 대기 ~ 거래완료) 단계에서만 거래 상대방의 배송지를
// 공개합니다. 클라이언트가 users/{uid}.address를 직접 읽을 수 있게 만들면
// Firestore 보안 규칙만으로 "이 거래의 당사자에게만" 공개하는 걸 안전하게
// 보장하기 어려워서, 서버(Admin SDK)에서 자격을 확인한 뒤 상대방 주소만
// 골라서 돌려주는 방식으로 구현했습니다.
const REVEALED_ADDRESS_STATUSES = ['winner_pending', 'second_pending', 'third_pending', 'paid', 'shipped', 'delivered', 'completed'];

exports.getTradeAddress = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');

  const productId = request.data?.productId;
  if (!productId || typeof productId !== 'string') {
    throw new HttpsError('invalid-argument', 'productId가 필요합니다.');
  }

  const productSnap = await db.collection('products').doc(productId).get();
  if (!productSnap.exists) throw new HttpsError('not-found', '상품을 찾을 수 없습니다.');
  const product = productSnap.data();

  const sellerId = product.sellerId || null;
  const winnerId = product.winnerId || product.buyerId || null;

  if (!winnerId || !sellerId || !REVEALED_ADDRESS_STATUSES.includes(product.status)) {
    throw new HttpsError('failed-precondition', '낙찰이 확정된 거래에서만 배송지를 확인할 수 있어요.');
  }

  let targetUid;
  if (uid === sellerId) {
    targetUid = winnerId;
  } else if (uid === winnerId) {
    targetUid = sellerId;
  } else {
    throw new HttpsError('permission-denied', '이 거래의 당사자만 배송지를 확인할 수 있어요.');
  }

  const targetSnap = await db.collection('users').doc(targetUid).get();
  const address = targetSnap.data()?.address || null;
  if (!address || !String(address.address1 || '').trim()) {
    return {available: false};
  }

  return {
    available: true,
    nickname: targetSnap.data()?.nickname || null,
    postcode: address.postcode || '',
    address1: address.address1 || '',
    address2: address.address2 || '',
  };
});

// ===== 토스페이먼츠 결제 승인 =====
// 앱(웹뷰)에서 결제 인증이 끝나면 successUrl로 돌아오고, 클라이언트가
// paymentKey/orderId/amount를 이 함수로 보냅니다. 여기서 토스 결제 승인 API를
// 호출해야 실제로 결제가 완료돼요(승인 전에는 금액이 차감되지 않습니다).
//
// 아래는 토스 "문서용 테스트 시크릿 키"예요. 전자결제 신청이 승인되면
// 발급받은 실제 시크릿 키로 바꾸고, 되도록 Secret Manager에 넣어서 쓰세요.
//   firebase functions:secrets:set TOSS_SECRET_KEY
// 시크릿 키는 절대 클라이언트/깃허브 등 외부에 노출되면 안 됩니다.
const TOSS_SECRET_KEY = 'test_gsk_docs_OaPz8L5KdmQXkzRz3y47BMw6';

// 포트원(PortOne) V2 결제 검증·취소용 API 시크릿. Secret Manager에 등록해서 씁니다.
//   firebase functions:secrets:set PORTONE_API_SECRET
// (포트원 콘솔에서 발급한 V2 API Secret. 절대 클라이언트/깃허브 등에 노출 금지.
//  채팅 등에 노출됐다면 반드시 콘솔에서 재발급 후 이 시크릿을 다시 설정하세요.)
const portoneApiSecret = defineSecret('PORTONE_API_SECRET');

// 스마트택배(스위트트래커) 배송조회 API 키. 배송완료 자동감지에 씁니다.
//   firebase functions:secrets:set SMART_PARCEL_API_KEY
// (스위트트래커에서 발급받은 키. 절대 클라이언트/깃허브 등에 노출 금지.)
// 키가 없으면 자동감지는 동작하지 않고, 구매자 수동 '상품 받았어요'로 처리돼요.
const smartParcelKey = defineSecret('SMART_PARCEL_API_KEY');

/** 결제 완료 후, 판매자에게 채팅으로 "배송 진행 + 송장(운송장) 번호 입력" 안내
 *  메시지를 자동으로 보냅니다. 메시지는 구매자(낙찰자) 명의로 채팅방에 남기고,
 *  onNewChatMessage 트리거가 판매자에게 푸시 알림까지 자동으로 보내줍니다.
 *  채팅방 id 규칙은 앱과 동일하게 '{productId}_{정렬한 두 uid}'를 씁니다.
 *  실패해도 결제 응답에는 영향이 없도록 예외를 삼킵니다. */
async function notifySellerAfterPayment(productId) {
  try {
    const productSnap = await db.collection('products').doc(productId).get();
    if (!productSnap.exists) return;
    const product = productSnap.data();
    const sellerId = product.sellerId || null;
    const buyerId = product.winnerId || product.buyerId || null;
    if (!sellerId || !buyerId || sellerId === buyerId) return;
    const title = product.title || '상품';

    const sortedUsers = [buyerId, sellerId].sort();
    const roomId = `${productId}_${sortedUsers.join('_')}`;
    const roomRef = db.collection('chatRooms').doc(roomId);

    const messageText =
      `[결제 완료] "${title}" 결제가 완료되었어요! 💳\n` +
      "'내 경매 관리 > 판매'에서 [운송장 등록] 버튼으로 배송 정보를 등록해주세요. " +
      '등록하면 구매자에게 배송 정보가 자동으로 전달돼요.';

    const roomSnap = await roomRef.get();
    const existing = roomSnap.exists ? (roomSnap.data() || {}) : {};
    const participants = Array.from(new Set([
      buyerId,
      sellerId,
      ...(Array.isArray(existing.participants) ? existing.participants : []),
    ]));
    const unread = Object.assign({}, existing.unreadCounts || {});
    unread[sellerId] = (unread[sellerId] || 0) + 1;
    if (unread[buyerId] === undefined) unread[buyerId] = 0;

    await roomRef.set({
      productId: productId,
      productTitle: title,
      productImageUrl: product.coverImageUrl || product.imageUrl || null,
      productPrice: product.price || null,
      productStatus: 'paid',
      sellerUid: sellerId,
      sellerName: product.sellerName || null,
      buyerUid: buyerId,
      participants: participants,
      lastMessage: messageText,
      lastMessageType: 'text',
      lastSenderUid: buyerId,
      lastMessageAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ...(roomSnap.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      unreadCounts: unread,
    }, {merge: true});

    await roomRef.collection('messages').add({
      text: messageText,
      senderUid: buyerId,
      createdAt: FieldValue.serverTimestamp(),
      readBy: [buyerId],
      type: 'text',
    });
  } catch (e) {
    console.error('[toss-confirm] 판매자 결제완료 알림 실패', e);
  }
}

exports.confirmTossPayment = onCall(async (request) => {
  // 결제 승인은 토스가 paymentKey/orderId/amount로 최종 검증하므로, 여기서는
  // 로그인(auth) 컨텍스트가 없어도 막지 않아요. 로그인 정보가 있으면 그 uid를,
  // 없으면 클라이언트가 보낸 buyerId를 쓰고, 둘 다 없으면 null로 둡니다.
  const uid = request.auth?.uid || (request.data && request.data.buyerId) || null;

  const {paymentKey, orderId, amount, productId} = request.data || {};
  if (!paymentKey || !orderId || typeof amount !== 'number') {
    throw new HttpsError('invalid-argument', '결제 정보가 올바르지 않습니다.');
  }

  // 토스 결제 승인 API 호출. 시크릿 키 뒤에 콜론(:)을 붙여 base64로 인코딩한
  // 값을 Basic 인증 헤더로 사용합니다.
  const basicAuth = Buffer.from(`${TOSS_SECRET_KEY}:`).toString('base64');
  let tossRes;
  let tossJson;
  try {
    tossRes = await fetch('https://api.tosspayments.com/v1/payments/confirm', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${basicAuth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({paymentKey, orderId, amount}),
    });
    tossJson = await tossRes.json();
  } catch (e) {
    console.error('[toss-confirm] 네트워크 오류', e);
    throw new HttpsError('unavailable', '결제 승인 요청에 실패했어요. 잠시 후 다시 시도해주세요.');
  }

  if (!tossRes.ok) {
    console.error('[toss-confirm] 승인 실패', tossJson);
    throw new HttpsError(
        'failed-precondition',
        (tossJson && tossJson.message) || '결제 승인에 실패했어요.');
  }

  // 결제 내역 저장 + 상품 상태를 '결제완료(paid)'로 갱신합니다. 승인은 이미
  // 끝났으므로, 여기서 실패해도 결제 자체는 성공으로 응답하고 로그만 남깁니다.
  try {
    await db.collection('payments').doc(orderId).set({
      orderId,
      paymentKey,
      amount,
      productId: productId || null,
      buyerId: uid,
      status: tossJson.status || 'DONE',
      method: tossJson.method || null,
      approvedAt: tossJson.approvedAt || null,
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    if (productId && typeof productId === 'string') {
      const productUpdate = {
        status: 'paid',
        paidAt: FieldValue.serverTimestamp(),
        paymentKey,
        paymentOrderId: orderId,
        paidAmount: amount,
      };
      // uid가 있을 때만 buyerId를 기록해요. 경매 마감 시 이미 winnerId/buyerId가
      // 저장돼 있으므로, uid가 없다고 null로 덮어쓰면 안 돼요.
      if (uid) productUpdate.buyerId = uid;
      await db.collection('products').doc(productId).set(productUpdate, {merge: true});
    }
  } catch (e) {
    console.error('[toss-confirm] 결과 저장 실패', e);
  }

  // 판매자에게 채팅으로 결제완료 + 배송/송장번호 안내를 자동 발송해요.
  if (productId && typeof productId === 'string') {
    await notifySellerAfterPayment(productId);
  }

  return {
    success: true,
    orderId,
    paymentKey,
    amount,
    status: tossJson.status || 'DONE',
    method: tossJson.method || null,
    approvedAt: tossJson.approvedAt || null,
  };
});

/** 포트원(PortOne) V2 결제 검증. 클라이언트가 결제창에서 받은 paymentId를 보내면,
 *  서버가 포트원 REST API로 실제 결제 상태(PAID)와 금액을 조회해 검증합니다.
 *  금액은 상품의 기대 금액(낙찰가 + 배송비)과 서버에서 대조하므로, 클라이언트가
 *  보낸 금액을 신뢰하지 않아요(위변조 방지). 검증되면 상품을 'paid'로 갱신하고
 *  판매자에게 결제완료를 알립니다. */
exports.confirmPortonePayment = onCall({secrets: [portoneApiSecret]}, async (request) => {
  const uid = request.auth?.uid || (request.data && request.data.buyerId) || null;
  const {paymentId, productId} = request.data || {};
  if (!paymentId || typeof paymentId !== 'string') {
    throw new HttpsError('invalid-argument', '결제 정보가 올바르지 않습니다.');
  }

  // 포트원 REST API로 실제 결제를 조회해요. 인증 헤더는 'PortOne {API_SECRET}' 형식.
  let payment;
  try {
    const res = await fetch(
      `https://api.portone.io/payments/${encodeURIComponent(paymentId)}`,
      {headers: {'Authorization': `PortOne ${portoneApiSecret.value()}`}},
    );
    payment = await res.json();
    if (!res.ok) {
      console.error('[portone-confirm] 조회 실패', res.status, payment);
      throw new HttpsError('failed-precondition', (payment && payment.message) || '결제 확인에 실패했어요.');
    }
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    console.error('[portone-confirm] 네트워크 오류', e);
    throw new HttpsError('unavailable', '결제 확인 요청에 실패했어요. 잠시 후 다시 시도해주세요.');
  }

  if (payment.status !== 'PAID') {
    console.error('[portone-confirm] 미결제 상태', payment.status);
    throw new HttpsError('failed-precondition', '결제가 완료되지 않았어요.');
  }

  const paidAmount = Number(payment.amount && payment.amount.total) || 0;

  // 서버 측 금액 검증: 상품의 기대 금액(낙찰가 + 배송비)과 실제 결제액이 일치해야 함.
  if (productId && typeof productId === 'string') {
    const snap = await db.collection('products').doc(productId).get();
    if (snap.exists) {
      const pd = snap.data();
      const expected = Number(pd.currentPrice || 0) + Number(pd.shippingFee || 0);
      if (expected > 0 && paidAmount !== expected) {
        console.error('[portone-confirm] 금액 불일치', {paymentId, paidAmount, expected});
        throw new HttpsError('failed-precondition', '결제 금액이 주문 금액과 일치하지 않아요.');
      }
    }
  }

  // 결제 기록 저장 + 상품 상태 'paid'로 갱신(실패해도 결제 자체는 성공 응답).
  try {
    await db.collection('payments').doc(paymentId).set({
      paymentId,
      amount: paidAmount,
      productId: productId || null,
      buyerId: uid,
      status: payment.status,
      method: (payment.method && payment.method.type) || null,
      pgProvider: (payment.channel && payment.channel.pgProvider) || null,
      paidAt: payment.paidAt || null,
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    if (productId && typeof productId === 'string') {
      const productUpdate = {
        status: 'paid',
        paidAt: FieldValue.serverTimestamp(),
        paymentId,
        paidAmount,
      };
      if (uid) productUpdate.buyerId = uid;
      await db.collection('products').doc(productId).set(productUpdate, {merge: true});
    }
  } catch (e) {
    console.error('[portone-confirm] 결과 저장 실패', e);
  }

  if (productId && typeof productId === 'string') {
    await notifySellerAfterPayment(productId);
  }

  return {
    success: true,
    paymentId,
    amount: paidAmount,
    status: payment.status,
    method: (payment.method && payment.method.type) || null,
    paidAt: payment.paidAt || null,
  };
});

// ===== 본인인증(KG이니시스 통합인증) 검증 =====
// 판매(경매) 등록 전 필수 본인인증이에요. 클라이언트가 포트원 SDK(통합인증 채널)로
// 인증을 마치면 identityVerificationId를 넘겨주고, 서버가 포트원 REST API로 실제
// 인증 결과(VERIFIED)를 확인한 뒤 사용자 문서에 인증 상태와 최소 정보를 저장합니다.
// CI(사람마다 고유값)를 저장해 제재·차단 계정의 재가입/중복가입을 막는 데 씁니다.
exports.confirmIdentityVerification = onCall({secrets: [portoneApiSecret]}, async (request) => {
  const uid = request.auth?.uid || null;
  if (!uid) {
    throw new HttpsError('unauthenticated', '로그인 후 본인인증을 진행해주세요.');
  }
  const {identityVerificationId} = request.data || {};
  if (!identityVerificationId || typeof identityVerificationId !== 'string') {
    throw new HttpsError('invalid-argument', '본인인증 정보가 올바르지 않습니다.');
  }

  // 포트원 REST API로 본인인증 결과를 조회해요. 인증 헤더는 'PortOne {API_SECRET}' 형식.
  let idv;
  try {
    const res = await fetch(
      `https://api.portone.io/identity-verifications/${encodeURIComponent(identityVerificationId)}`,
      {headers: {'Authorization': `PortOne ${portoneApiSecret.value()}`}},
    );
    idv = await res.json();
    if (!res.ok) {
      console.error('[portone-idv] 조회 실패', res.status, idv);
      throw new HttpsError('failed-precondition', (idv && idv.message) || '본인인증 확인에 실패했어요.');
    }
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    console.error('[portone-idv] 네트워크 오류', e);
    throw new HttpsError('unavailable', '본인인증 확인 요청에 실패했어요. 잠시 후 다시 시도해주세요.');
  }

  if (idv.status !== 'VERIFIED') {
    console.error('[portone-idv] 미인증 상태', idv.status);
    throw new HttpsError('failed-precondition', '본인인증이 완료되지 않았어요.');
  }

  const vc = idv.verifiedCustomer || {};
  const ci = vc.ci || null;
  const name = vc.name || null;
  const phone = vc.phoneNumber || null;

  // CI 기반 중복/재가입 차단: 같은 명의(CI)로 이미 다른 계정이 인증했다면 막아요.
  // (테스트 채널은 CI가 없을 수 있는데, 그 경우엔 이 검사를 건너뜁니다.)
  if (ci) {
    try {
      const dup = await db.collection('users').where('identityCi', '==', ci).limit(3).get();
      const otherUid = dup.docs.map((d) => d.id).find((id) => id !== uid);
      if (otherUid) {
        console.warn('[portone-idv] 이미 인증된 CI로 중복 시도', {uid, otherUid});
        throw new HttpsError('already-exists', '이미 다른 계정에서 본인인증된 명의예요. 한 명의당 한 계정만 인증할 수 있어요.');
      }
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error('[portone-idv] 중복 CI 조회 실패(무시하고 진행)', e);
    }
  }

  try {
    await db.collection('users').doc(uid).set({
      identityVerified: true,
      identityVerifiedAt: FieldValue.serverTimestamp(),
      identityVerificationId,
      verifiedName: name,
      verifiedPhone: phone,
      identityCi: ci,
      identityBirthDate: vc.birthDate || null,
      identityGender: vc.gender || null,
    }, {merge: true});
  } catch (e) {
    console.error('[portone-idv] 저장 실패', e);
    throw new HttpsError('internal', '본인인증 저장에 실패했어요. 잠시 후 다시 시도해주세요.');
  }

  return {verified: true, name};
});

// ===== 배송 마감 자동화 =====
// 결제(paid) 이후 배송이 제때 진행되지 않는 건을 단계별로 처리합니다.
//   1) 결제 후 3일 안에 '배송 준비'를 시작하지 않으면 → 자동 결제취소(환불)
//   2) '배송 준비' 후 3일 안에 운송장 미등록 → 판매자에게 경고 안내 + 푸시
//   3) '배송 준비' 후 7일 안에 운송장 미등록 → 낙찰자에게 채팅으로
//      [결제취소]/[배송요청 다시] 버튼을 띄워 선택하게 함
// 운송장이 등록되면 상품 상태가 'paid'→'shipped'로 바뀌므로, 아래 스케줄러는
// status == 'paid'인 건만 조회하면 됩니다.
const DAY_MS = 24 * 60 * 60 * 1000;
const AUTO_CANCEL_NO_PREPARE_DAYS = 3; // 결제 후 배송준비 없이 이 일수가 지나면 자동취소
const WARN_AFTER_PREPARE_DAYS = 3;     // 배송준비 후 이 일수가 지나면 판매자 경고
const DECISION_AFTER_PREPARE_DAYS = 7; // 배송준비 후 이 일수가 지나면 낙찰자 선택

const AUTO_CONFIRM_AFTER_SHIP_DAYS = 3; // 배송확인 알림(또는 수령표시) 후 이 일수가 지나면 자동 구매확정
const DELIVERY_CHECK_AFTER_SHIP_DAYS = 7; // 발송(운송장 등록) 후 이 일수에 '상품 받으셨나요?' 첫 확인 알림
const DELIVERY_RECHECK_INTERVAL_DAYS = 7; // [받지 못했어요] 이후 이 간격(일)으로 재확인 알림을 반복

exports.checkShippingDeadlines = onSchedule(
    {schedule: 'every 60 minutes', secrets: [smartParcelKey]}, async () => {
    const nowMs = Date.now();

    // (A) 결제완료(paid) 건: 배송 준비/운송장 기한 점검
    const paidSnap = await db
      .collection('products')
      .where('status', '==', 'paid')
      .get();
    if (!paidSnap.empty) {
      console.log(`배송 기한 점검 대상 ${paidSnap.size}건`);
      const results = await Promise.allSettled(
        paidSnap.docs.map((doc) => processShippingDeadline(doc, nowMs)),
      );
      logFailures('배송 기한 점검', results);
    }

    // (B) 배송중(shipped)·배송완료(delivered) 건:
    //   - 배송중이면 먼저 택배사 배송완료를 자동 감지해서 delivered로 승격
    //     (detectCarrierDelivery — API 키 연동 전까지는 아무 것도 안 하는 스텁)
    //   - 그 뒤 발송 후 일정 기간이 지나면 자동 구매확정(거래완료) 처리
    for (const status of ['shipped', 'delivered']) {
      const snap = await db.collection('products').where('status', '==', status).get();
      if (snap.empty) continue;
      const results = await Promise.allSettled(
        snap.docs.map(async (doc) => {
          if (status === 'shipped') {
            await detectCarrierDelivery(doc, nowMs);
            // 배송예정일 즈음 '상품 받으셨나요?' 확인 알림(+미수령 시 재확인 반복)
            await processDeliveryCheck(doc, nowMs);
          }
          await autoConfirmIfOverdue(doc, nowMs);
        }),
      );
      logFailures(`배송 상태 점검(${status})`, results);
    }
});

/** 발송 후 AUTO_CONFIRM_AFTER_SHIP_DAYS일이 지나도 구매확정이 없으면 자동으로
 *  거래완료 처리합니다. */
async function autoConfirmIfOverdue(doc, nowMs) {
  const ref = doc.ref;
  // 트랜잭션으로 '자동 확정'을 선점해요. 구매자의 수동 구매확정(confirmPurchase)이나
  // 겹치는 다음 스케줄 실행과 동시에 돌아도, 상태를 다시 읽어 확인하므로 중복
  // 완료·중복 알림이 발생하지 않아요.
  let claimed = null;
  try {
    claimed = await db.runTransaction(async (tx) => {
      const s = await tx.get(ref);
      if (!s.exists) return null;
      const p = s.data();
      if (p.status !== 'shipped' && p.status !== 'delivered') return null;
      if (p.completedAt) return null; // 이미 확정됨
      // 구매자가 '받지 못했어요'로 미수령을 알린 건은 분쟁이 열린 상태이므로 절대
      // 자동 확정하지 않아요(구매자가 '받았어요'를 누르거나 별도 해결 시까지 보류).
      if (p.deliveryDisputeOpen === true) return null;
      // 기준 시각:
      //  - 배송완료(delivered, 구매자가 '받았어요' 누름): deliveredAt + N일.
      //  - 배송중(shipped): '상품 받으셨나요?' 확인 알림(deliveryCheckSentAt)을 보낸
      //    뒤 N일간 응답이 없을 때만 자동 확정해요. 알림 전(=발송 후 예정일 전)에는
      //    보류해서, 구매자가 수령 여부를 답할 기회를 반드시 보장합니다.
      let base;
      if (p.status === 'delivered' && p.deliveredAt && typeof p.deliveredAt.toMillis === 'function') {
        base = p.deliveredAt;
      } else if (p.status === 'shipped') {
        if (!p.deliveryCheckSentAt || typeof p.deliveryCheckSentAt.toMillis !== 'function') {
          return null; // 아직 수령 확인 알림 전 → 자동 확정 보류
        }
        base = p.deliveryCheckSentAt;
      } else {
        base = (p.shippedAt && typeof p.shippedAt.toMillis === 'function') ? p.shippedAt : p.paidAt;
      }
      if (!base || typeof base.toMillis !== 'function') return null;
      const days = (nowMs - base.toMillis()) / DAY_MS;
      if (days < AUTO_CONFIRM_AFTER_SHIP_DAYS) return null;
      tx.update(ref, {
        status: 'completed',
        completedAt: FieldValue.serverTimestamp(),
        autoConfirmed: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return p;
    });
  } catch (e) {
    console.error('[ship-deadline] 자동 구매확정 트랜잭션 실패', ref.id, e);
    return;
  }
  if (!claimed) return;
  const p = claimed;
  const title = p.title || '상품';
  await postRoomMessage(ref.id, p, {
    text: `배송 후 ${AUTO_CONFIRM_AFTER_SHIP_DAYS}일이 지나 자동으로 구매확정(거래완료)되었어요. 🎉`,
    type: 'system',
    senderUid: p.sellerId || null,
  });
  await sendPushToUser(p.winnerId || p.buyerId, {
    title: '거래가 자동 완료됐어요',
    body: `"${title}" 배송 후 ${AUTO_CONFIRM_AFTER_SHIP_DAYS}일이 지나 자동 구매확정되었어요.`,
    data: {type: 'purchase_confirmed', productId: ref.id},
  });
}

/** 발송(shipped) 후 배송예정일 즈음 구매자에게 '상품 받으셨나요?' 확인 알림을 보내고,
 *  구매자가 '받지 못했어요'로 미수령을 알린 경우 일정 간격으로 재확인 알림을 보냅니다.
 *  (택배 추적 API가 붙기 전에도 동작하도록 발송 시각 기준으로 예정일을 근사합니다.
 *   택배 API가 연동되면 배송완료 시점 기준으로 바꾸면 더 정확해요.) */
async function processDeliveryCheck(doc, nowMs) {
  try {
    const p = doc.data();
    if (p.status !== 'shipped' || p.completedAt) return;
    const shippedAt = (p.shippedAt && typeof p.shippedAt.toMillis === 'function') ? p.shippedAt : null;
    if (!shippedAt) return;
    const title = p.title || '상품';
    const buyerId = p.winnerId || p.buyerId || null;

    // (1) 첫 확인 알림: 발송 후 DELIVERY_CHECK_AFTER_SHIP_DAYS일이 지났고 아직 안 보냈으면.
    if (!p.deliveryCheckSentAt) {
      const days = (nowMs - shippedAt.toMillis()) / DAY_MS;
      if (days < DELIVERY_CHECK_AFTER_SHIP_DAYS) return;
      await postRoomMessage(doc.ref.id, p, {
        text: `"${title}" 상품을 받으셨나요? 받으셨다면 [받았어요]를, 아직 못 받으셨다면 [받지 못했어요]를 눌러주세요.`,
        type: 'delivery_check',
        senderUid: p.sellerId || null,
      });
      await doc.ref.set({
        deliveryCheckSentAt: FieldValue.serverTimestamp(),
        deliveryCheckCount: 1,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await sendPushToUser(buyerId, {
        title: '상품을 받으셨나요?',
        body: `"${title}" 수령 여부를 확인해주세요.`,
        data: {type: 'delivery_check', productId: doc.ref.id},
      });
      return;
    }

    // (2) 재확인 알림: '받지 못했어요'로 분쟁이 열린 건은 일정 간격으로 반복해요.
    if (p.deliveryDisputeOpen === true && typeof p.deliveryCheckNextAtMs === 'number') {
      if (nowMs < p.deliveryCheckNextAtMs) return;
      await postRoomMessage(doc.ref.id, p, {
        text: `"${title}" 상품을 이제 받으셨나요? 받으셨다면 [받았어요]를, 아직이라면 [받지 못했어요]를 눌러주세요.`,
        type: 'delivery_check',
        senderUid: p.sellerId || null,
      });
      await doc.ref.set({
        deliveryCheckCount: (typeof p.deliveryCheckCount === 'number' ? p.deliveryCheckCount : 1) + 1,
        deliveryCheckNextAtMs: nowMs + DELIVERY_RECHECK_INTERVAL_DAYS * DAY_MS,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await sendPushToUser(buyerId, {
        title: '상품을 받으셨나요?',
        body: `"${title}" 수령 여부를 다시 확인해주세요.`,
        data: {type: 'delivery_check', productId: doc.ref.id},
      });
    }
  } catch (e) {
    console.error('[delivery-check] 처리 실패', doc.ref.id, e);
  }
}

/** 낙찰자(구매자)가 배송 확인 알림에서 '받지 못했어요'를 눌렀을 때 호출됩니다.
 *  미수령 분쟁을 열어 자동 구매확정을 보류하고, 일정 간격 재확인을 예약합니다. */
exports.reportNotReceived = onCall(async (request) => {
  const uid = request.auth?.uid || null;
  const {productId} = request.data || {};
  if (!productId || typeof productId !== 'string') {
    throw new HttpsError('invalid-argument', 'productId가 필요합니다.');
  }
  const ref = db.collection('products').doc(productId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', '상품을 찾을 수 없습니다.');
  const p = snap.data();
  const buyerId = p.winnerId || p.buyerId || null;
  if (!uid || uid !== buyerId) {
    throw new HttpsError('permission-denied', '낙찰자만 수령 여부를 알릴 수 있어요.');
  }
  if (p.status !== 'shipped') {
    throw new HttpsError('failed-precondition', '배송중 상태에서만 확인할 수 있어요.');
  }
  const nowMs = Date.now();
  await ref.set({
    deliveryDisputeOpen: true,
    deliveryNotReceivedAt: FieldValue.serverTimestamp(),
    deliveryCheckNextAtMs: nowMs + DELIVERY_RECHECK_INTERVAL_DAYS * DAY_MS,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await postRoomMessage(productId, p, {
    text: `아직 상품을 받지 못하셨군요. ${DELIVERY_RECHECK_INTERVAL_DAYS}일 후 다시 확인 알림을 보내드릴게요. 배송에 문제가 있다면 판매자와 상의하시고, 필요하면 결제취소(환불)를 도와드려요. 상품을 받으시면 [받았어요]를 눌러주세요.`,
    type: 'system',
    senderUid: p.sellerId || null,
  });
  await sendPushToUser(p.sellerId, {
    title: '구매자가 미수령을 알렸어요',
    body: `"${p.title || '상품'}" 구매자가 아직 상품을 받지 못했다고 해요. 배송 상태를 확인해주세요.`,
    data: {type: 'delivery_not_received', productId},
  });
  return {success: true};
});

// ═══════════════════════════════════════════════════════════════════════════
//  [배송완료 자동 감지 훅 — 스마트택배(스위트트래커) 연동됨]
//  ※ SMART_PARCEL_API_KEY 를 설정하면 자동 동작, 없으면 수동 수령표시로 처리 ※
// ───────────────────────────────────────────────────────────────────────────
//  택배 추적 API 키가 준비되면 이 함수 "하나만" 채우면, 위 스케줄러
//  (checkShippingDeadlines)가 1시간마다 배송중(shipped) 건의 송장을 조회해서
//  '배송완료'를 자동으로 잡아 status='delivered' + deliveredAt 을 세팅해줘요.
//  구매자 수동 '상품 받았어요'(markDelivered)는 그대로 병행 — 자동 감지가 늦거나
//  실패해도 구매자가 직접 확정할 수 있어요.
//
//  연동 방법 (둘 중 택1):
//   A) 스마트택배(스위트트래커) 폴링:  https://info.sweettracker.co.kr/apidoc
//      1. 키 발급 → Secret 등록:  firebase functions:secrets:set SMART_PARCEL_API_KEY
//      2. 파일 상단(defineSecret 근처)에:
//           const smartParcelKey = defineSecret('SMART_PARCEL_API_KEY');
//      3. checkShippingDeadlines 선언을 다음처럼 secrets 옵션 형태로 바꾸기:
//           onSchedule({schedule: 'every 60 minutes', secrets: [smartParcelKey]}, async () => {...})
//      4. 조회 URL:
//           https://info.sweettracker.co.kr/api/v1/trackingInfo
//             ?t_key={KEY}&t_code={택배사코드}&t_invoice={송장번호}
//         응답의  level === 6  또는  complete === true  이면 배송완료.
//      5. 같은 송장 1일 20회 조회 제한 → lastTrackedAt 을 저장해 3~6시간 간격으로만 조회.
//   B) Delivery Tracker 웹훅(거의 실시간):  https://tracker.delivery/
//      운송장 등록 시 추적 등록 → 배송완료 콜백을 받는 onRequest 함수를 별도 추가.
//
//  택배사 코드 매핑: 앱의 shippingCourier(택배사 이름, AppCouriers) → API 택배사 코드.
//    아래 CARRIER_CODE 예시를 실제 코드표(위 API 문서) 기준으로 채우고, 매칭 안 되면
//    자동 감지는 스킵(수동 표시로 처리)하면 됩니다.
//
//  참고: 자동 감지가 켜지면 자동 구매확정 기준도 '발송 후 N일'(AUTO_CONFIRM_AFTER_
//    SHIP_DAYS) 대신 '배송완료(deliveredAt) 후 N일'로 바꾸면 배송 지연에도 더 공정해요.
//
//  아래 예시 구현(전부 주석)을 참고해 채우세요. 실제 코드로 옮기려면 함수 안의
//  'return;' 을 지우고 블록 주석을 해제한 뒤, CARRIER_CODE 를 채우면 됩니다.
// ═══════════════════════════════════════════════════════════════════════════
// 스마트택배(스위트트래커) 택배사 코드. 앱의 택배사명(shippingCourier)을 정규화한 뒤
// 키워드로 매칭해요. 매칭이 안 되면 자동 감지를 건너뛰고 수동 수령표시로 처리합니다.
// (코드 표: https://info.sweettracker.co.kr/apidoc — companylist API로도 조회 가능)
function sweetTrackerCarrierCode(courierName) {
  const n = String(courierName || '').replace(/\s|택배|주식회사|\(주\)/g, '');
  if (!n) return null;
  if (n.includes('대한통운') || n.includes('CJ')) return '04';
  if (n.includes('우체국') || n.includes('EMS')) return '01';
  if (n.includes('한진')) return '05';
  if (n.includes('롯데') || n.includes('현대')) return '08';
  if (n.includes('로젠')) return '06';
  if (n.includes('GS') || n.includes('포스트박스') || n.includes('Postbox')) return '24';
  if (n.includes('CU') || n.includes('CVS')) return '46';
  if (n.includes('경동')) return '23';
  if (n.includes('대신')) return '22';
  if (n.includes('일양')) return '11';
  if (n.includes('합동')) return '32';
  if (n.includes('홈픽')) return '54';
  return null;
}

async function detectCarrierDelivery(doc, nowMs) {
  // 스마트택배(스위트트래커) 폴링으로 배송완료를 자동 감지해요. API 키
  // (SMART_PARCEL_API_KEY)가 없으면 아무 것도 하지 않고, 구매자 수동 수령표시
  // (markDelivered)로 처리합니다.
  let apiKey;
  try {
    apiKey = smartParcelKey.value();
  } catch (_) {
    apiKey = '';
  }
  if (!apiKey) return;

  const p = doc.data();
  if (p.status !== 'shipped' || p.completedAt) return;
  const invoice = String(p.shippingTrackingNumber || '').trim();
  if (!invoice) return;
  const code = sweetTrackerCarrierCode(p.shippingCourier);
  if (!code) return; // 택배사 코드 매핑이 없으면 자동 감지 스킵(수동 표시로 처리)

  // 조회 과금/제한 보호: 마지막 조회 후 3시간이 안 지났으면 건너뛰기
  // (같은 송장 1일 조회 횟수 제한이 있어 3~6시간 간격 폴링이 적당해요).
  const last = p.lastTrackedAt;
  if (last && typeof last.toMillis === 'function' &&
      (nowMs - last.toMillis()) < 3 * 60 * 60 * 1000) return;

  let json;
  try {
    const url = 'https://info.sweettracker.co.kr/api/v1/trackingInfo' +
      `?t_key=${encodeURIComponent(apiKey)}&t_code=${code}` +
      `&t_invoice=${encodeURIComponent(invoice)}`;
    const res = await fetch(url);
    json = await res.json();
  } catch (e) {
    console.error('[carrier] 배송조회 실패', doc.ref.id, e);
    return; // 실패 시 lastTrackedAt을 갱신하지 않아 다음 주기에 재시도해요.
  }
  // 조회를 실제로 수행했으면 다음 폴링까지 간격을 둬요(성공/무효 응답 공통).
  await doc.ref.set({lastTrackedAt: FieldValue.serverTimestamp()}, {merge: true});

  // 스마트택배 응답: level 6(배송완료) 또는 complete === true 이면 배송완료.
  const delivered = json && (Number(json.level) === 6 || json.complete === true);
  if (!delivered) return;

  await doc.ref.set({
    status: 'delivered',
    deliveredAt: FieldValue.serverTimestamp(),
    deliveryDisputeOpen: false, // 미수령 분쟁이 열려 있었다면 해제(배송완료 확인)
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await postRoomMessage(doc.ref.id, p, {
    text: '택배사 배송완료가 확인됐어요. ✅ 상품을 확인한 뒤 구매확정을 눌러주세요.',
    type: 'system',
    senderUid: p.sellerId || null,
  });
  await sendPushToUser(p.winnerId || p.buyerId, {
    title: '상품이 배송완료됐어요',
    body: `"${p.title || '상품'}" 배송이 완료됐어요. 확인 후 구매확정을 눌러주세요.`,
    data: {type: 'delivered', productId: doc.ref.id},
  });
}

async function processShippingDeadline(doc, nowMs) {
  const p = doc.data();

  // 운송장이 이미 등록된 건은 건너뜁니다(방어적 확인).
  if (p.shippingTrackingNumber && String(p.shippingTrackingNumber).trim()) return;

  const prepared = p.shippingPreparedAt;

  // (1) 아직 배송 준비를 시작하지 않은 경우: 결제 시각 기준으로 판단
  if (!prepared) {
    const paidAt = p.paidAt;
    if (!paidAt || typeof paidAt.toMillis !== 'function') return;
    const days = (nowMs - paidAt.toMillis()) / DAY_MS;
    if (days >= AUTO_CANCEL_NO_PREPARE_DAYS) {
      await autoCancelForNoPrepare(doc.ref, p);
    }
    return;
  }

  // (2)(3) 배송 준비를 시작한 경우: 준비 시각 기준으로 판단
  if (typeof prepared.toMillis !== 'function') return;
  const days = (nowMs - prepared.toMillis()) / DAY_MS;

  if (days >= DECISION_AFTER_PREPARE_DAYS) {
    // 7일 경과 → 낙찰자에게 선택 요청(이미 요청했거나 처리됐으면 생략)
    if (!p.shipDecisionRequestedAt && !p.shipDecisionResolvedAt) {
      await postBuyerShipDecision(doc.ref, p);
    }
  } else if (days >= WARN_AFTER_PREPARE_DAYS) {
    // 3일 경과 → 판매자 경고(한 번만)
    if (!p.shipPrepareWarnedAt) {
      await warnSellerNoTracking(doc.ref, p);
    }
  }
}

/** (1) 결제 후 배송 준비가 없어 자동 결제취소(환불) 처리합니다. */
async function autoCancelForNoPrepare(ref, p) {
  const title = p.title || '상품';
  const reason = '판매자 미배송 (결제 후 3일 내 배송 준비 없음)';
  const buyerId = p.winnerId || p.buyerId || null;
  const sellerId = p.sellerId || null;

  // 환불하기 '전에' 트랜잭션으로 상태를 다시 확인하고 선점해요. 스케줄러가
  // 1시간 전 스냅샷으로 판단하는 사이 판매자가 운송장을 등록해 'shipped'가 됐을
  // 수 있는데, 그대로 환불하면 '배송된 상품을 환불'하는 사고가 나요. 여기서
  // status가 여전히 'paid'이고 운송장·배송준비가 없을 때만 선점(autoCancelClaimedAt)
  // 하고, 아니면 이번 취소를 취소해요. 중복 실행(중복 환불)도 이 선점으로 막혀요.
  let claimed = false;
  try {
    claimed = await db.runTransaction(async (tx) => {
      const s = await tx.get(ref);
      if (!s.exists) return false;
      const d = s.data();
      if (d.status !== 'paid') return false;
      if (d.shippingTrackingNumber && String(d.shippingTrackingNumber).trim()) return false;
      if (d.shippingPreparedAt) return false;
      if (d.autoCancelClaimedAt) return false; // 이미 취소 처리 중
      tx.update(ref, {autoCancelClaimedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
      return true;
    });
  } catch (e) {
    console.error('[ship-deadline] 자동취소 선점 실패', ref.id, e);
    return;
  }
  if (!claimed) return;

  const ok = await cancelTossPaymentInternal(p, reason);
  if (!ok) {
    // 환불에 실패하면 선점을 해제해 다음 실행 때 다시 시도합니다(상태는 그대로 paid).
    try {
      await ref.set({autoCancelClaimedAt: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    } catch (_) { /* 해제 실패해도 다음 트랜잭션이 재확인하니 안전 */ }
    console.error(`[ship-deadline] 자동취소 환불 실패: ${ref.id}`);
    return;
  }

  await ref.set({
    status: 'cancelled',
    cancelledAt: FieldValue.serverTimestamp(),
    cancelReason: reason,
    shipDecisionResolvedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  await postRoomMessage(ref.id, p, {
    text: `배송이 시작되지 않아 결제가 자동으로 취소(환불)되었어요. (${reason})`,
    type: 'system',
    senderUid: sellerId,
  });
  // 채팅 메시지로 낙찰자에게는 onNewChatMessage가 알림을 보내주고,
  // 발신자(판매자)에게는 여기서 직접 알림을 보냅니다.
  await sendPushToUser(sellerId, {
    title: '거래가 자동 취소됐어요',
    body: `"${title}" 배송 준비가 없어 결제가 자동 취소(환불)되었어요.`,
    data: {type: 'payment_cancelled', productId: ref.id},
  });
}

/** (2) 배송 준비 후 3일이 지나도 운송장이 없으면 판매자에게 경고합니다. */
async function warnSellerNoTracking(ref, p) {
  const title = p.title || '상품';
  const sellerId = p.sellerId || null;

  // 경고 발송을 트랜잭션으로 선점(shipPrepareWarnedAt)해요. 겹치는 실행이나
  // 그사이 운송장 등록(→shipped)이 있으면 경고를 보내지 않아 중복/오발송을 막아요.
  let claimed = false;
  try {
    claimed = await db.runTransaction(async (tx) => {
      const s = await tx.get(ref);
      if (!s.exists) return false;
      const d = s.data();
      if (d.status !== 'paid') return false;
      if (d.shippingTrackingNumber && String(d.shippingTrackingNumber).trim()) return false;
      if (d.shipPrepareWarnedAt) return false;
      tx.update(ref, {shipPrepareWarnedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
      return true;
    });
  } catch (e) {
    console.error('[ship-deadline] 판매자 경고 선점 실패', ref.id, e);
    return;
  }
  if (!claimed) return;

  await postRoomMessage(ref.id, p, {
    text:
      '배송 준비를 시작한 지 3일이 지났어요. 배송 준비 후 7일 안에 운송장을 등록해야 해요. ' +
      '7일 안에 등록되지 않으면 구매자 요청에 따라 결제가 취소될 수 있어요.',
    type: 'system',
    senderUid: sellerId,
  });
  await sendPushToUser(sellerId, {
    title: '운송장 등록이 필요해요',
    body: `"${title}" 배송 준비 후 7일 안에 운송장을 등록해주세요. 미등록 시 결제가 취소될 수 있어요.`,
    data: {type: 'shipping_reminder', productId: ref.id},
  });
}

/** (3) 배송 준비 후 7일이 지나도 운송장이 없으면 낙찰자에게 선택을 요청합니다. */
async function postBuyerShipDecision(ref, p) {
  const title = p.title || '상품';
  const sellerId = p.sellerId || null;

  // 선택 요청을 트랜잭션으로 선점(shipDecisionRequestedAt)해요. 겹치는 실행이나
  // 이미 해결된 건(shipDecisionResolvedAt)·운송장 등록이 있으면 중복 요청을 막아요.
  let claimed = false;
  try {
    claimed = await db.runTransaction(async (tx) => {
      const s = await tx.get(ref);
      if (!s.exists) return false;
      const d = s.data();
      if (d.status !== 'paid') return false;
      if (d.shippingTrackingNumber && String(d.shippingTrackingNumber).trim()) return false;
      if (d.shipDecisionRequestedAt || d.shipDecisionResolvedAt) return false;
      tx.update(ref, {shipDecisionRequestedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
      return true;
    });
  } catch (e) {
    console.error('[ship-deadline] 배송 선택요청 선점 실패', ref.id, e);
    return;
  }
  if (!claimed) return;

  // type: 'ship_decision' 메시지를 판매자 명의로 남기면, 앱에서 낙찰자에게만
  // [결제취소]/[배송요청 다시] 버튼을 보여주고, onNewChatMessage가 낙찰자에게
  // 새 메시지 알림(채팅으로 딥링크)을 보내줍니다.
  await postRoomMessage(ref.id, p, {
    text:
      `배송 준비 후 7일이 지났는데 아직 "${title}"의 운송장이 등록되지 않았어요.\n` +
      '결제를 취소(환불)하거나, 판매자에게 배송을 다시 요청할 수 있어요.',
    type: 'ship_decision',
    senderUid: sellerId,
  });
}

/** 토스페이먼츠 결제 취소(환불) API를 호출합니다. 성공하면 true.
 *  paymentKey는 상품 문서(paymentKey) 또는 결제 문서(payments/{orderId})에서
 *  찾습니다. 실패해도 예외를 던지지 않고 false를 돌려줘, 호출한 쪽이 상태를
 *  섣불리 '취소'로 바꾸지 않도록 합니다. */
async function cancelTossPaymentInternal(product, reason) {
  try {
    let paymentKey = product.paymentKey || null;
    const orderId = product.paymentOrderId || null;
    if (!paymentKey && orderId) {
      const paySnap = await db.collection('payments').doc(orderId).get();
      if (paySnap.exists) paymentKey = paySnap.data().paymentKey || null;
    }
    if (!paymentKey) {
      console.error('[toss-cancel] paymentKey를 찾을 수 없어요.', {orderId});
      return false;
    }

    const basicAuth = Buffer.from(`${TOSS_SECRET_KEY}:`).toString('base64');
    const res = await fetch(
      `https://api.tosspayments.com/v1/payments/${encodeURIComponent(paymentKey)}/cancel`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${basicAuth}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({cancelReason: reason || '구매자 요청'}),
      },
    );
    const json = await res.json();
    if (!res.ok) {
      console.error('[toss-cancel] 취소 실패', json);
      return false;
    }

    const resolvedOrderId = orderId || json.orderId || null;
    if (resolvedOrderId) {
      await db.collection('payments').doc(resolvedOrderId).set({
        status: json.status || 'CANCELED',
        cancelReason: reason || '구매자 요청',
        cancelledAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return true;
  } catch (e) {
    console.error('[toss-cancel] 오류', e);
    return false;
  }
}

/** 낙찰자(구매자)가 '결제취소' 버튼을 눌렀을 때 호출됩니다. 환불 후 상품을
 *  'cancelled'로 바꾸고 채팅에 안내를 남깁니다. */
exports.cancelTossPayment = onCall(async (request) => {
  const uid = request.auth?.uid || null;
  const {productId, reason} = request.data || {};
  if (!productId || typeof productId !== 'string') {
    throw new HttpsError('invalid-argument', 'productId가 필요합니다.');
  }

  const ref = db.collection('products').doc(productId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', '상품을 찾을 수 없습니다.');
  const p = snap.data();
  const buyerId = p.winnerId || p.buyerId || null;
  const sellerId = p.sellerId || null;

  // 결제 취소(환불)는 되돌릴 수 없으므로, 이 거래의 당사자만 허용합니다.
  if (!uid || (uid !== buyerId && uid !== sellerId)) {
    throw new HttpsError('permission-denied', '이 거래의 당사자만 결제를 취소할 수 있어요.');
  }
  if (p.status === 'cancelled') return {success: true, alreadyCancelled: true};
  if (p.status !== 'paid') {
    throw new HttpsError('failed-precondition', '결제 완료 상태에서만 취소할 수 있어요.');
  }

  const cancelReason = (typeof reason === 'string' && reason.trim())
    ? reason.trim()
    : '구매자 요청 (배송 지연)';

  const ok = await cancelTossPaymentInternal(p, cancelReason);
  if (!ok) {
    throw new HttpsError('failed-precondition', '결제 취소(환불)에 실패했어요. 잠시 후 다시 시도해주세요.');
  }

  await ref.set({
    status: 'cancelled',
    cancelledAt: FieldValue.serverTimestamp(),
    cancelReason,
    shipDecisionResolvedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  // 낙찰자 명의로 안내를 남기면 onNewChatMessage가 판매자에게 알림을 보내줍니다.
  await postRoomMessage(productId, p, {
    text: `결제가 취소(환불)되었어요. (${cancelReason})`,
    type: 'system',
    senderUid: buyerId,
  });

  return {success: true};
});

/** 낙찰자(구매자)가 '배송요청 다시' 버튼을 눌렀을 때 호출됩니다. 배송 준비
 *  시계를 다시 시작하고 판매자에게 운송장 등록을 재요청합니다. */
exports.requestShipmentAgain = onCall(async (request) => {
  const uid = request.auth?.uid || null;
  const {productId} = request.data || {};
  if (!productId || typeof productId !== 'string') {
    throw new HttpsError('invalid-argument', 'productId가 필요합니다.');
  }

  const ref = db.collection('products').doc(productId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', '상품을 찾을 수 없습니다.');
  const p = snap.data();
  const buyerId = p.winnerId || p.buyerId || null;
  const sellerId = p.sellerId || null;

  if (!uid || uid !== buyerId) {
    throw new HttpsError('permission-denied', '낙찰자만 배송을 다시 요청할 수 있어요.');
  }
  if (p.status !== 'paid') {
    throw new HttpsError('failed-precondition', '결제 완료 상태에서만 배송을 다시 요청할 수 있어요.');
  }

  // 배송 준비 시각을 지금으로 재설정하고 경고/선택 기록을 지워, 판매자에게
  // 다시 7일의 배송 기한을 부여합니다.
  await ref.set({
    shippingPreparedAt: FieldValue.serverTimestamp(),
    shipPrepareWarnedAt: FieldValue.delete(),
    shipDecisionRequestedAt: FieldValue.delete(),
    shipDecisionResolvedAt: FieldValue.delete(),
    reshipRequestedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  // 낙찰자 명의로 남기면 onNewChatMessage가 판매자에게 알림을 보내줍니다.
  await postRoomMessage(productId, p, {
    text: '구매자가 배송을 다시 요청했어요. 판매자님, 운송장을 등록해주세요. 🚚',
    type: 'system',
    senderUid: buyerId,
  });

  return {success: true};
});

/** 특정 거래(상품)의 채팅방에 메시지를 남기는 공용 헬퍼입니다. 채팅방 문서를
 *  최신 정보로 갱신하고(unread 카운트 포함) 메시지를 추가합니다. 채팅방 id
 *  규칙은 앱과 동일하게 '{productId}_{정렬한 두 uid}'예요. 실패해도 예외를
 *  던지지 않습니다. */
async function postRoomMessage(productId, product, {text, type = 'system', senderUid}) {
  try {
    const sellerId = product.sellerId || null;
    const buyerId = product.winnerId || product.buyerId || null;
    if (!sellerId || !buyerId || sellerId === buyerId) return;
    const title = product.title || '상품';
    const sender = senderUid || sellerId;
    const recipient = sender === sellerId ? buyerId : sellerId;

    const sortedUsers = [buyerId, sellerId].sort();
    const roomId = `${productId}_${sortedUsers.join('_')}`;
    const roomRef = db.collection('chatRooms').doc(roomId);

    const roomSnap = await roomRef.get();
    const existing = roomSnap.exists ? (roomSnap.data() || {}) : {};
    const participants = Array.from(new Set([
      buyerId,
      sellerId,
      ...(Array.isArray(existing.participants) ? existing.participants : []),
    ]));
    const unread = Object.assign({}, existing.unreadCounts || {});
    unread[recipient] = (unread[recipient] || 0) + 1;
    if (unread[sender] === undefined) unread[sender] = 0;

    await roomRef.set({
      productId: productId,
      productTitle: title,
      productImageUrl: product.coverImageUrl || product.imageUrl || null,
      productPrice: product.price || null,
      productStatus: product.status || null,
      sellerUid: sellerId,
      sellerName: product.sellerName || null,
      buyerUid: buyerId,
      participants: participants,
      lastMessage: text,
      lastMessageType: type === 'image' ? 'image' : 'text',
      lastSenderUid: sender,
      lastMessageAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ...(roomSnap.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      unreadCounts: unread,
    }, {merge: true});

    await roomRef.collection('messages').add({
      text: text,
      senderUid: sender,
      createdAt: FieldValue.serverTimestamp(),
      readBy: [sender],
      type: type,
      productId: productId,
    });
  } catch (e) {
    console.error('[chat] 메시지 게시 실패', e);
  }
}

/** 낙찰자(구매자)가 '판매자에게 확인요청'을 눌렀을 때 호출됩니다. 결제가 완료됐으니
 *  배송 준비를 시작해달라는 안내를 채팅으로 다시 보내고, 판매자에게 푸시를 보내요. */
exports.requestSellerConfirm = onCall(async (request) => {
  const uid = request.auth?.uid || null;
  const {productId} = request.data || {};
  if (!productId || typeof productId !== 'string') {
    throw new HttpsError('invalid-argument', 'productId가 필요합니다.');
  }
  const snap = await db.collection('products').doc(productId).get();
  if (!snap.exists) throw new HttpsError('not-found', '상품을 찾을 수 없습니다.');
  const p = snap.data();
  const buyerId = p.winnerId || p.buyerId || null;
  const sellerId = p.sellerId || null;
  if (!uid || uid !== buyerId) {
    throw new HttpsError('permission-denied', '낙찰자만 확인을 요청할 수 있어요.');
  }
  if (p.status !== 'paid') {
    throw new HttpsError('failed-precondition', '결제 완료 상태에서만 확인을 요청할 수 있어요.');
  }
  const title = p.title || '상품';
  await postRoomMessage(productId, p, {
    text: `구매자가 확인을 요청했어요. "${title}" 결제가 완료됐으니 [배송 준비 시작]을 눌러 배송을 진행해주세요. 🐥`,
    type: 'system',
    senderUid: buyerId,
  });
  await sendPushToUser(sellerId, {
    title: '구매자가 배송을 기다리고 있어요',
    body: `"${title}" 결제가 완료됐어요. 배송 준비를 시작해주세요.`,
    data: {type: 'seller_confirm_request', productId},
  });
  return {success: true};
});

/** 낙찰자(구매자)가 '상품 받았어요'(수령 표시)를 눌렀을 때 호출됩니다.
 *  상태를 '배송완료(delivered)'로 바꾸고 채팅으로 알려요. */
exports.markDelivered = onCall(async (request) => {
  const uid = request.auth?.uid || null;
  const {productId} = request.data || {};
  if (!productId || typeof productId !== 'string') {
    throw new HttpsError('invalid-argument', 'productId가 필요합니다.');
  }
  const ref = db.collection('products').doc(productId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', '상품을 찾을 수 없습니다.');
  const p = snap.data();
  const buyerId = p.winnerId || p.buyerId || null;
  if (!uid || uid !== buyerId) {
    throw new HttpsError('permission-denied', '낙찰자만 수령을 표시할 수 있어요.');
  }
  if (p.status !== 'shipped') {
    throw new HttpsError('failed-precondition', '배송중 상태에서만 수령을 표시할 수 있어요.');
  }
  await ref.set({
    status: 'delivered',
    deliveredAt: FieldValue.serverTimestamp(),
    deliveryDisputeOpen: false, // 미수령 분쟁이 열려 있었다면 해제(수령 확정)
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await postRoomMessage(productId, p, {
    text: '구매자가 상품을 받았어요. ✅ 확인 후 구매확정을 진행할 수 있어요.',
    type: 'system',
    senderUid: buyerId,
  });
  return {success: true};
});

/** 낙찰자(구매자)가 '구매확정'을 눌렀을 때 호출됩니다. 상태를 '거래완료(completed)'로
 *  바꾸고 양쪽에 알려요. */
exports.confirmPurchase = onCall(async (request) => {
  const uid = request.auth?.uid || null;
  const {productId} = request.data || {};
  if (!productId || typeof productId !== 'string') {
    throw new HttpsError('invalid-argument', 'productId가 필요합니다.');
  }
  const ref = db.collection('products').doc(productId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', '상품을 찾을 수 없습니다.');
  const p = snap.data();
  const buyerId = p.winnerId || p.buyerId || null;
  const sellerId = p.sellerId || null;
  if (!uid || uid !== buyerId) {
    throw new HttpsError('permission-denied', '낙찰자만 구매확정을 할 수 있어요.');
  }
  if (p.status !== 'shipped' && p.status !== 'delivered') {
    throw new HttpsError('failed-precondition', '배송중·배송완료 상태에서만 구매확정을 할 수 있어요.');
  }
  await ref.set({
    status: 'completed',
    completedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  const title = p.title || '상품';
  await postRoomMessage(productId, p, {
    text: '구매확정이 완료되어 거래가 종료됐어요. 🎉 이용해주셔서 감사해요!',
    type: 'system',
    senderUid: buyerId,
  });
  await sendPushToUser(sellerId, {
    title: '구매확정됐어요',
    body: `"${title}" 구매자가 구매확정했어요. 거래가 완료됐어요. 🎉`,
    data: {type: 'purchase_confirmed', productId},
  });
  return {success: true};
});

// ════════════════════════════════════════════════════════════════════════
//  AI 추천가 (웹 시세 검색 기반)
//  ------------------------------------------------------------------------
//  사진·제목·태그·카테고리로 "지금 이 굿즈가 웹에서 실제로 얼마에 거래되는지"
//  평균 시세를 추정해 추천가를 돌려줘요. 세 소스를 병행해요:
//   1) 내부 데이터 : 덕옥션에 쌓인 '완료된 경매'의 실제 낙찰가 중앙값
//   2) 네이버 쇼핑 : 같은 키워드의 현재 판매가(lprice) 평균
//   3) OpenAI 웹검색: GPT가 웹(번개장터/중고나라 등)을 검색해 추정한 중고 시세
//  블렌딩 원칙(사용자 요청): "내부 데이터 우선 + 웹 보조".
//   · 내부 표본이 충분(REC_MIN_INTERNAL건 이상)하면 내부값을 주로,
//     웹값으로 살짝 보정(W_INTERNAL:W_WEB).
//   · 표본이 부족한 초기엔 웹값(네이버+OpenAI)만으로 추천.
//   · 셋 다 실패하면 null → 앱이 규칙 기반 추정치로 폴백.
//  키(OPENAI_API_KEY / NAVER_CLIENT_ID / NAVER_CLIENT_SECRET)가 없는 소스는
//  자동으로 건너뛰어요.
// ════════════════════════════════════════════════════════════════════════
const REC_MIN_INTERNAL = 5; // 내부 데이터를 '주 소스'로 쓰기 위한 최소 표본 수
const REC_W_INTERNAL = 0.6; // 내부+웹 둘 다 있을 때 내부값 가중치
const REC_W_WEB = 0.4; //      〃                      웹값 가중치
// 비용 방어: uid당 시간당 호출 상한 + 같은 조건 결과 캐시(TTL).
const REC_RATE_LIMIT = 20; //        uid당 REC_RATE_WINDOW_MS 안에서 최대 호출 수
const REC_RATE_WINDOW_MS = 60 * 60 * 1000;
const REC_CACHE_TTL_MS = 6 * 60 * 60 * 1000; // 같은 제목·태그·카테고리·상태면 이 시간 동안 재사용

// 같은 조건(제목·태그·카테고리·상태)이면 캐시 키가 같아요. 이미지는 키에서 제외해
// (제목/태그가 시세를 좌우) 반복 호출 비용을 아껴요.
function recCacheKey({title, tags, category, condition}) {
  const norm = [
    (title || '').trim().toLowerCase(),
    (tags || []).map((t) => String(t).trim().toLowerCase()).sort().join(','),
    (category || '').trim().toLowerCase(),
    (condition || '').trim().toLowerCase(),
  ].join('|');
  return crypto.createHash('sha1').update(norm).digest('hex');
}

// uid당 시간당 호출 상한(토글 남용/스크립트 호출로 외부 API 비용이 폭주하는 것 방지).
// rateLimits/rec_{uid} 문서에 롤링 윈도우 카운터를 둬요. 상한 초과면 false.
async function recCheckRateLimit(uid) {
  const ref = db.collection('rateLimits').doc(`rec_${uid}`);
  const nowMs = Date.now();
  try {
    return await db.runTransaction(async (tx) => {
      const s = await tx.get(ref);
      const d = s.exists ? s.data() : null;
      if (!d || !d.windowStart || (nowMs - d.windowStart) > REC_RATE_WINDOW_MS) {
        tx.set(ref, {windowStart: nowMs, count: 1, updatedAt: FieldValue.serverTimestamp()});
        return true;
      }
      if ((d.count || 0) >= REC_RATE_LIMIT) return false;
      tx.update(ref, {count: (d.count || 0) + 1, updatedAt: FieldValue.serverTimestamp()});
      return true;
    });
  } catch (e) {
    // 레이트리밋 저장 실패 시엔 막지 않고 통과시켜요(기능 우선).
    console.error('[rec] 레이트리밋 확인 실패', uid, e);
    return true;
  }
}
// 완료·판매 확정으로 '최종가가 굳은' 상품 상태들(내부 시세 표본).
const REC_SOLD_STATUSES = ['completed', 'sold', 'paid', 'shipped', 'delivered'];

function recMedian(nums) {
  const a = nums.filter((n) => Number.isFinite(n) && n > 0).sort((x, y) => x - y);
  if (a.length === 0) return null;
  const mid = Math.floor(a.length / 2);
  return a.length % 2 ? a[mid] : Math.round((a[mid - 1] + a[mid]) / 2);
}

function recAverageTrimmed(nums) {
  const a = nums.filter((n) => Number.isFinite(n) && n > 0).sort((x, y) => x - y);
  if (a.length === 0) return null;
  // 표본이 4개 이상이면 최고·최저 각 1개를 잘라 이상치 영향을 줄여요.
  const trimmed = a.length >= 4 ? a.slice(1, a.length - 1) : a;
  const sum = trimmed.reduce((s, n) => s + n, 0);
  return Math.round(sum / trimmed.length);
}

function recRoundTo(value, unit) {
  if (!Number.isFinite(value) || value <= 0) return 0;
  return Math.max(unit, Math.round(value / unit) * unit);
}

function recBuildKeywords(title, tags) {
  const set = new Set();
  for (const t of (tags || [])) {
    const k = String(t || '').trim().toLowerCase();
    if (k) set.add(k);
  }
  for (const w of String(title || '').toLowerCase().split(/[,\s]+/)) {
    const k = w.trim();
    if (k.length >= 2) set.add(k);
  }
  return [...set];
}

// 1) 내부 데이터: 완료된 경매 낙찰가 중앙값 --------------------------------
async function recInternalMedian(keywords) {
  if (!keywords.length) return {median: null, count: 0};
  let snap;
  try {
    snap = await db.collection('products')
        .where('status', 'in', REC_SOLD_STATUSES)
        .limit(400)
        .get();
  } catch (e) {
    console.error('[rec] 내부 데이터 조회 실패', e);
    return {median: null, count: 0};
  }
  const rows = [];
  snap.forEach((doc) => {
    const p = doc.data() || {};
    const hay = `${p.title || ''} ${(Array.isArray(p.tags) ? p.tags.join(' ') : '')}`.toLowerCase();
    if (!keywords.some((k) => hay.includes(k))) return;
    let price = Number(p.currentPrice || 0);
    if (!(price > 0)) {
      price = Number(String(p.price || '').replace(/[^0-9]/g, '')) || 0;
    }
    if (price > 0) {
      const ts = p.updatedAt && typeof p.updatedAt.toMillis === 'function' ? p.updatedAt.toMillis() : 0;
      rows.push({ts, price});
    }
  });
  rows.sort((a, b) => b.ts - a.ts); // 최근 거래 우선
  const recent = rows.slice(0, 50).map((r) => r.price);
  return {median: recMedian(recent), count: recent.length};
}

// 2) 네이버 쇼핑 현재 판매가 평균 ------------------------------------------
async function recNaverAverage(query, clientId, clientSecret) {
  if (!clientId || !clientSecret || !query) return {average: null, count: 0};
  try {
    const url = 'https://openapi.naver.com/v1/search/shop.json' +
      `?query=${encodeURIComponent(query)}&display=30&sort=sim`;
    const res = await fetch(url, {
      headers: {
        'X-Naver-Client-Id': clientId,
        'X-Naver-Client-Secret': clientSecret,
      },
    });
    if (!res.ok) {
      console.error('[rec] 네이버 응답 오류', res.status);
      return {average: null, count: 0};
    }
    const json = await res.json();
    const prices = (json.items || [])
        .map((it) => Number(it.lprice))
        .filter((n) => Number.isFinite(n) && n > 0);
    return {average: recAverageTrimmed(prices), count: prices.length};
  } catch (e) {
    console.error('[rec] 네이버 검색 실패', e);
    return {average: null, count: 0};
  }
}

// 3) OpenAI 웹검색 + 비전으로 중고 시세 추정 --------------------------------
async function recOpenAiEstimate({title, tags, category, condition, imageUrls, apiKey}) {
  if (!apiKey) return {price: null};
  const tagLine = (tags || []).join(', ');
  const prompt =
    '당신은 한국 애니메이션·캐릭터 굿즈 중고 거래 시세 분석가입니다.\n' +
    '아래 상품이 지금 한국에서 중고로 거래되는 평균 시세를 웹에서 검색해 추정하세요.\n' +
    '번개장터·중고나라·헬로마켓·트위터 나눔/양도 글 등 실제 거래가를 참고하고,\n' +
    '정가(신품)만 있으면 상태를 반영해 중고가로 보정하세요.\n' +
    `- 상품명: ${title || '(없음)'}\n` +
    `- 카테고리: ${category || '(없음)'}\n` +
    `- 태그: ${tagLine || '(없음)'}\n` +
    `- 상태: ${condition || '(없음)'}\n` +
    '반드시 아래 JSON 한 줄만 출력하세요(설명 문장 금지):\n' +
    '{"price_krw": <정수 원>, "low": <정수 원>, "high": <정수 원>, "basis": "<한 줄 근거>"}';

  const content = [{type: 'input_text', text: prompt}];
  for (const u of (imageUrls || []).slice(0, 2)) {
    if (typeof u === 'string' && u.length > 0) {
      // detail:'low' — 시세 인식엔 저해상도로 충분해서 비전 토큰 비용을 크게 줄여요.
      content.push({type: 'input_image', image_url: u, detail: 'low'});
    }
  }
  try {
    const res = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        tools: [{type: 'web_search_preview'}],
        input: [{role: 'user', content}],
      }),
    });
    if (!res.ok) {
      const errTxt = await res.text().catch(() => '');
      console.error('[rec] OpenAI 응답 오류', res.status, errTxt.slice(0, 300));
      return {price: null};
    }
    const json = await res.json();
    // Responses API: output_text 헬퍼가 있으면 그걸, 없으면 output 배열을 훑어요.
    let text = typeof json.output_text === 'string' ? json.output_text : '';
    if (!text && Array.isArray(json.output)) {
      for (const item of json.output) {
        for (const c of (item.content || [])) {
          if (typeof c.text === 'string') text += c.text;
        }
      }
    }
    // 본문에서 JSON 객체를 추출해 파싱해요(모델이 앞뒤에 군더더기를 붙여도 견뎌요).
    // 반드시 price_krw JSON 필드만 가격으로 인정해요. 예전엔 JSON이 없을 때
    // 본문 속 아무 숫자(예: "2025년")나 가격으로 오인하는 버그가 있어서 제거했어요.
    const m = text.match(/\{[\s\S]*\}/);
    if (m) {
      try {
        const obj = JSON.parse(m[0]);
        const price = Number(obj.price_krw);
        // 굿즈 시세로 말이 되는 하한(1,000원) 이상만 채택해요.
        if (Number.isFinite(price) && price >= 1000) {
          return {price, low: Number(obj.low) || null, high: Number(obj.high) || null, basis: obj.basis || null};
        }
      } catch (_) { /* JSON 파싱 실패 → 값 없음 처리 */ }
    }
    return {price: null};
  } catch (e) {
    console.error('[rec] OpenAI 호출 실패', e);
    return {price: null};
  }
}

exports.recommendPrice = onCall(
    {
      timeoutSeconds: 120,
      memory: '512MiB',
    },
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new HttpsError('unauthenticated', '로그인 후 이용할 수 있어요.');
      }
      const data = request.data || {};
      const title = typeof data.title === 'string' ? data.title.trim() : '';
      const tags = Array.isArray(data.tags) ? data.tags.map((t) => String(t)).filter(Boolean) : [];
      const category = typeof data.category === 'string' ? data.category : '';
      const condition = typeof data.condition === 'string' ? data.condition : '';
      // 이미지: 업로드된 URL(imageUrls) 또는 등록 화면의 즉석 data URL(imageDataUrls).
      const imageUrls = [
        ...(Array.isArray(data.imageUrls) ? data.imageUrls : []),
        ...(Array.isArray(data.imageDataUrls) ? data.imageDataUrls : []),
      ].filter((u) => typeof u === 'string' && u.length > 0);

      if (!title && tags.length === 0) {
        throw new HttpsError('invalid-argument', '제목이나 태그를 먼저 입력해주세요.');
      }

      // 캐시 확인: 같은 조건(제목·태그·카테고리·상태)이면 외부 API 호출 없이 재사용해요.
      const cacheKey = recCacheKey({title, tags, category, condition});
      const cacheRef = db.collection('recommendCache').doc(cacheKey);
      try {
        const cached = await cacheRef.get();
        const cd = cached.exists ? cached.data() : null;
        if (cd && cd.success && cd.expiresAt && typeof cd.expiresAt.toMillis === 'function' &&
            cd.expiresAt.toMillis() > Date.now() && cd.payload) {
          return {...cd.payload, method: 'cache'};
        }
      } catch (e) {
        console.error('[rec] 캐시 조회 실패', e);
      }

      // uid당 시간당 호출 상한 — 캐시 미스인 '비싼 경로'에만 적용해요(남용/스크립트 방지).
      const allowed = await recCheckRateLimit(request.auth.uid);
      if (!allowed) {
        throw new HttpsError('resource-exhausted', '추천가 요청이 잠시 많아요. 잠시 후 다시 시도해주세요.');
      }

      const keywords = recBuildKeywords(title, tags);
      const query = (title || tags.join(' ')).trim();

      // 세 소스를 동시에 조회해요(하나가 느려도 나머지는 진행).
      const [internal, naver, openai] = await Promise.all([
        recInternalMedian(keywords),
        recNaverAverage(query, process.env.NAVER_CLIENT_ID, process.env.NAVER_CLIENT_SECRET),
        recOpenAiEstimate({
          title, tags, category, condition, imageUrls,
          apiKey: process.env.OPENAI_API_KEY,
        }),
      ]);

      // 웹값 = 네이버 평균과 OpenAI 추정의 평균(있는 것만).
      const webParts = [];
      if (naver.average && naver.average > 0) webParts.push(naver.average);
      if (openai.price && openai.price > 0) webParts.push(openai.price);
      const webPrice = webParts.length ? Math.round(webParts.reduce((s, n) => s + n, 0) / webParts.length) : null;

      const internalStrong = internal.median && internal.count >= REC_MIN_INTERNAL;
      let finalPrice = null;
      let method = 'none';
      if (internalStrong && webPrice) {
        finalPrice = Math.round(REC_W_INTERNAL * internal.median + REC_W_WEB * webPrice);
        method = 'internal+web';
      } else if (internalStrong) {
        finalPrice = internal.median;
        method = 'internal';
      } else if (webPrice) {
        finalPrice = webPrice;
        method = 'web';
      }

      if (!finalPrice || finalPrice <= 0) {
        // 어떤 소스도 값을 못 냈어요 → 앱이 규칙 기반 폴백을 쓰도록 신호.
        // (실패는 캐시하지 않아요 — 다음에 사진·태그를 보완하면 다시 시도되게.)
        return {
          success: false,
          price: 0,
          method: 'none',
          internalCount: internal.count,
          naverCount: naver.count,
          sampleCount: (internal.count || 0) + (naver.count || 0),
          hasOpenAi: !!(openai.price && openai.price > 0),
        };
      }

      const payload = {
        success: true,
        price: recRoundTo(finalPrice, 500),
        method,
        internalCount: internal.count,
        internalMedian: internal.median || 0,
        naverAverage: naver.average || 0,
        naverCount: naver.count,
        openAiPrice: openai.price || 0,
        openAiBasis: openai.basis || null,
        // 사용자에게 보여줄 '분석에 쓴 표본 수'(내부 + 네이버 아이템 수).
        sampleCount: (internal.count || 0) + (naver.count || 0),
      };
      // 성공 결과만 캐시에 저장(TTL 동안 같은 조건 재사용).
      try {
        await cacheRef.set({
          success: true,
          payload,
          expiresAt: Timestamp.fromMillis(Date.now() + REC_CACHE_TTL_MS),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } catch (e) {
        console.error('[rec] 캐시 저장 실패', e);
      }
      return payload;
    });

// ════════════════════════════════════════════════════════════════════════
//  입찰권(출시 이벤트) 시스템 — 서버 코어
//  ------------------------------------------------------------------------
//  경제 구조:
//   · 지급(+): 가입 3, 폰인증 1, 배송지 등록 1, 결제수단 등록 1(자리만),
//              경매 등록 1(10분 내 삭제 시 회수), 일반 경매 입찰 1, 낙찰 1
//   · 소모(-): 최저가 경매 입찰 1  (consumeBidTicket 콜러블)
//  원칙: 잔액(users.bidTickets)과 원장(users/{uid}/ticketLedger)은 '서버만' 써요.
//        클라이언트는 읽기만(규칙에서 잠금). 모든 지급/소모/회수는 아래 트리거·
//        콜러블에서만 일어나서 앱 조작으로 발급 불가.
//  멱등성: 원장 문서 id로 중복 지급을 막아요. 1회성 지급은 사유(reason)만,
//          건별 지급은 사유_참조id(reason_refId)를 id로 써요.
//  ※ 앱 UI(잔액 표시·부족 안내·제재 문구)는 다음 단계에서 얹어요. 여긴 코어만.
// ════════════════════════════════════════════════════════════════════════
const TICKET = {
  SIGNUP: 3,
  PHONE_VERIFIED: 1,
  ADDRESS_REGISTERED: 1,
  PAYMENT_METHOD: 1, // ※ 결제수단 등록 기능이 붙을 때 연결(지금은 자리만).
  AUCTION_REGISTER: 1,
  BID_NORMAL: 1, // 일반 경매 입찰 시 지급
  AUCTION_WON: 1,
  LOWEST_BID_COST: 1, // 최저가 경매 입찰 시 소모
};
const TICKET_RECLAIM_WINDOW_MS = 10 * 60 * 1000; // 등록 후 이 시간 내 삭제 시 회수

/** 지급/차감을 원장 기록과 함께 한 트랜잭션으로 처리해요. 같은 ledgerId면 다시
 *  실행돼도 중복 적립이 안 돼요(멱등). refId를 주면 '건별', 안 주면 '1회성 지급'. */
async function ticketGrant(uid, amount, reason, refId) {
  if (!uid || !amount) return false;
  const userRef = db.collection('users').doc(uid);
  const ledgerId = refId ? `${reason}_${refId}` : reason;
  const ledgerRef = userRef.collection('ticketLedger').doc(ledgerId);
  try {
    return await db.runTransaction(async (tx) => {
      const led = await tx.get(ledgerRef);
      if (led.exists) return false; // 이미 지급됨
      tx.set(ledgerRef, {
        type: amount >= 0 ? 'grant' : 'debit',
        amount, reason, refId: refId || null,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(userRef, {
        bidTickets: FieldValue.increment(amount),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });
  } catch (e) {
    console.error('[ticket] 지급 실패', uid, reason, refId, e);
    return false;
  }
}

/** 지급을 되돌려요(회수). 원래 지급 원장이 있고 아직 회수 안 했을 때만 차감. */
async function ticketReclaim(uid, amount, reason, refId) {
  if (!uid || !amount || !refId) return false;
  const userRef = db.collection('users').doc(uid);
  const grantRef = userRef.collection('ticketLedger').doc(`${reason}_${refId}`);
  const reclaimRef = userRef.collection('ticketLedger').doc(`${reason}_reclaim_${refId}`);
  try {
    return await db.runTransaction(async (tx) => {
      const grant = await tx.get(grantRef);
      if (!grant.exists) return false; // 지급된 적 없음 → 회수 없음
      const reclaimed = await tx.get(reclaimRef);
      if (reclaimed.exists) return false; // 이미 회수함
      tx.set(reclaimRef, {
        type: 'reclaim', amount: -amount, reason, refId,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(userRef, {
        bidTickets: FieldValue.increment(-amount),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });
  } catch (e) {
    console.error('[ticket] 회수 실패', uid, reason, refId, e);
    return false;
  }
}

/** 잔액에서 차감(소모)해요. 잔액이 부족하면 {ok:false}. */
async function ticketConsume(uid, amount, reason, refId) {
  const userRef = db.collection('users').doc(uid);
  const ledgerRef = userRef.collection('ticketLedger').doc();
  return db.runTransaction(async (tx) => {
    const u = await tx.get(userRef);
    const bal = (u.exists && Number(u.data().bidTickets)) || 0;
    if (bal < amount) return {ok: false, balance: bal};
    tx.set(ledgerRef, {
      type: 'consume', amount: -amount, reason, refId: refId || null,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.set(userRef, {
      bidTickets: FieldValue.increment(-amount),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {ok: true, balance: bal - amount};
  });
}

// ── 지급 트리거들 (기존 큰 함수는 건드리지 않고 독립 트리거로 얹어요) ──

/** 가입: users 문서가 생기면 3장. 생성 시 이미 폰인증/배송지가 있으면 그것도 지급. */
exports.grantSignupTickets = onDocumentCreated('users/{uid}', async (event) => {
  const uid = event.params.uid;
  const d = (event.data && event.data.data()) || {};
  await ticketGrant(uid, TICKET.SIGNUP, 'signup', null);
  if (d.phoneVerified === true) {
    await ticketGrant(uid, TICKET.PHONE_VERIFIED, 'phone_verified', null);
  }
  const addr1 = d.address && d.address.address1;
  if (addr1 && String(addr1).trim()) {
    await ticketGrant(uid, TICKET.ADDRESS_REGISTERED, 'address_registered', null);
  }
});

/** 폰인증(false→true)·배송지 등록(빈값→입력)·결제수단 등록 시 각각 1장. */
exports.grantProfileTickets = onDocumentUpdated('users/{uid}', async (event) => {
  const uid = event.params.uid;
  const before = (event.data && event.data.before && event.data.before.data()) || {};
  const after = (event.data && event.data.after && event.data.after.data()) || {};

  if (after.phoneVerified === true && before.phoneVerified !== true) {
    await ticketGrant(uid, TICKET.PHONE_VERIFIED, 'phone_verified', null);
  }

  const beforeAddr = (before.address && before.address.address1) ? String(before.address.address1).trim() : '';
  const afterAddr = (after.address && after.address.address1) ? String(after.address.address1).trim() : '';
  if (afterAddr && !beforeAddr) {
    await ticketGrant(uid, TICKET.ADDRESS_REGISTERED, 'address_registered', null);
  }

  // ── 결제수단 등록 지급(자리만) ──
  // 실제 결제수단 등록 기능이 붙으면, 그 등록 완료를 나타내는 필드
  // (예: paymentMethodRegistered:true)로 아래 주석을 살리면 바로 동작해요.
  //   if (after.paymentMethodRegistered === true && before.paymentMethodRegistered !== true) {
  //     await ticketGrant(uid, TICKET.PAYMENT_METHOD, 'payment_method', null);
  //   }
});

/** 경매 등록: 상품이 생기면 판매자에게 1장(상품당 1회). */
exports.grantAuctionRegisterTicket = onDocumentCreated('products/{productId}', async (event) => {
  const productId = event.params.productId;
  const p = (event.data && event.data.data()) || {};
  if (p.sellerId) {
    await ticketGrant(p.sellerId, TICKET.AUCTION_REGISTER, 'auction_register', productId);
  }
});

/** 경매 삭제: 등록 후 10분 이내면 등록 지급을 회수하고, 등록↔삭제 반복
 *  카운터(제재 판단용)를 올려요. */
exports.reclaimAuctionRegisterTicket = onDocumentDeleted('products/{productId}', async (event) => {
  const productId = event.params.productId;
  const p = (event.data && event.data.data()) || {};
  if (!p.sellerId) return;
  const created = p.createdAt;
  const createdMs = created && typeof created.toMillis === 'function' ? created.toMillis() : null;
  if (createdMs == null) return;
  if ((Date.now() - createdMs) <= TICKET_RECLAIM_WINDOW_MS) {
    await ticketReclaim(p.sellerId, TICKET.AUCTION_REGISTER, 'auction_register', productId);
    // 짧은 시간 내 등록↔삭제를 반복하는 어뷰징 추적(제재 판단 근거).
    await db.collection('users').doc(p.sellerId).set({
      auctionChurnCount: FieldValue.increment(1),
      lastAuctionChurnAt: FieldValue.serverTimestamp(),
    }, {merge: true}).catch(() => {});
  }
});

/** 일반 경매 입찰: 입찰마다 입찰자에게 1장(최저가 경매는 지급 안 함 — 그쪽은 소모). */
exports.grantBidTicket = onDocumentCreated('products/{productId}/bids/{bidId}', async (event) => {
  const {productId, bidId} = event.params;
  const bid = (event.data && event.data.data()) || {};
  const bidderUid = bid.userId;
  if (!bidderUid) return;
  const p = (await db.collection('products').doc(productId).get()).data() || {};
  if (p.auctionType === 'lowest') return; // 최저가 경매 입찰은 지급 대상 아님
  if (p.sellerId && p.sellerId === bidderUid) return; // 자기 경매 입찰 방어
  await ticketGrant(bidderUid, TICKET.BID_NORMAL, 'bid', bidId);
});

/** 낙찰: winnerId가 새로 정해지는 순간 그 낙찰자에게 1장(상품·낙찰자당 1회).
 *  1순위 낙찰은 물론, 2·3순위로 승격돼 새 낙찰자가 되는 경우도 각각 지급. */
exports.grantAuctionWonTicket = onDocumentUpdated('products/{productId}', async (event) => {
  const productId = event.params.productId;
  const before = (event.data && event.data.before && event.data.before.data()) || {};
  const after = (event.data && event.data.after && event.data.after.data()) || {};
  const w = after.winnerId;
  if (w && w !== before.winnerId) {
    await ticketGrant(w, TICKET.AUCTION_WON, 'auction_won', `${productId}_${w}`);
  }
});

// ── 소모(최저가 경매 입찰) ──
/** 최저가 경매 입찰 시 입찰권 1장을 소모해요. 앱(다음 단계)에서 최저가 경매에
 *  입찰을 넣기 직전에 이 콜러블을 호출하고, 실패(입찰권 부족)면 입찰을 막고
 *  "입찰권이 부족해요" 안내를 띄우면 돼요. 일반 경매면 소모 없이 통과시켜요. */
exports.consumeBidTicket = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', '로그인 후 이용할 수 있어요.');
  const {productId} = request.data || {};
  if (!productId || typeof productId !== 'string') {
    throw new HttpsError('invalid-argument', 'productId가 필요합니다.');
  }
  const p = (await db.collection('products').doc(productId).get()).data();
  if (!p) throw new HttpsError('not-found', '상품을 찾을 수 없습니다.');
  if (p.auctionType !== 'lowest') {
    return {ok: true, consumed: false}; // 일반 경매는 소모 없이 통과
  }
  const res = await ticketConsume(uid, TICKET.LOWEST_BID_COST, 'lowest_bid', productId);
  if (!res.ok) {
    throw new HttpsError('failed-precondition', '입찰권이 부족해요.', {balance: res.balance});
  }
  return {ok: true, consumed: true, balance: res.balance};
});
