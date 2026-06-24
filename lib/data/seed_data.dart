// Initial sample data so the app is useful on first launch.
import '../models/app_snapshot.dart';
import '../models/enums.dart';
import '../models/occasion_record.dart';
import '../models/person.dart';

AppSnapshot createSeedSnapshot() {
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 18);
  final earlierThisMonth = DateTime(now.year, now.month, 8);
  final lastMonth = DateTime(now.year, now.month - 1, 23);
  final twoMonthsAgo = DateTime(now.year, now.month - 2, 11);

  final people = <Person>[
    Person(
      id: 'person_1',
      name: '김민수',
      relationship: '친구',
      phoneNumber: '010-1234-5678',
      memo: '대학 동기',
      createdAt: now.subtract(const Duration(days: 45)),
    ),
    Person(
      id: 'person_2',
      name: '박영희',
      relationship: '친척',
      phoneNumber: '010-9876-5432',
      memo: '외삼촌 가족',
      createdAt: now.subtract(const Duration(days: 60)),
    ),
    Person(
      id: 'person_3',
      name: '이지은',
      relationship: '가족',
      memo: '조카 돌잔치',
      createdAt: now.subtract(const Duration(days: 30)),
    ),
    Person(
      id: 'person_4',
      name: '정우성',
      relationship: '회사',
      memo: '팀장님',
      createdAt: now.subtract(const Duration(days: 20)),
    ),
  ];

  final records = <OccasionRecord>[
    OccasionRecord(
      id: 'record_1',
      personId: 'person_1',
      personName: '김민수',
      relationship: '친구',
      eventType: EventType.wedding,
      date: thisMonth,
      amount: 100000,
      transactionType: TransactionType.given,
      location: '서울 웨딩홀',
      memo: '축하 메시지 전달',
      createdAt: thisMonth.subtract(const Duration(hours: 6)),
      updatedAt: thisMonth.subtract(const Duration(hours: 6)),
    ),
    OccasionRecord(
      id: 'record_2',
      personId: 'person_2',
      personName: '박영희',
      relationship: '친척',
      eventType: EventType.funeral,
      date: earlierThisMonth,
      amount: 50000,
      transactionType: TransactionType.received,
      location: '가족장례식장',
      memo: '조문 감사',
      createdAt: earlierThisMonth.subtract(const Duration(hours: 3)),
      updatedAt: earlierThisMonth.subtract(const Duration(hours: 3)),
    ),
    OccasionRecord(
      id: 'record_3',
      personId: 'person_3',
      personName: '이지은',
      relationship: '가족',
      eventType: EventType.firstBirthday,
      date: lastMonth,
      amount: 70000,
      transactionType: TransactionType.given,
      location: '강남 파티룸',
      memo: '돌잡이 참석',
      createdAt: lastMonth.subtract(const Duration(hours: 1)),
      updatedAt: lastMonth.subtract(const Duration(hours: 1)),
    ),
    OccasionRecord(
      id: 'record_4',
      personId: 'person_4',
      personName: '정우성',
      relationship: '회사',
      eventType: EventType.opening,
      date: thisMonth.subtract(const Duration(days: 2)),
      amount: 30000,
      transactionType: TransactionType.given,
      location: '판교 사무실',
      memo: '개업 축하',
      createdAt: thisMonth.subtract(const Duration(days: 2, hours: 1)),
      updatedAt: thisMonth.subtract(const Duration(days: 2, hours: 1)),
    ),
    OccasionRecord(
      id: 'record_5',
      personId: 'person_1',
      personName: '김민수',
      relationship: '친구',
      eventType: EventType.birthday,
      date: twoMonthsAgo,
      amount: 20000,
      transactionType: TransactionType.received,
      location: '동네 카페',
      memo: '생일 모임',
      createdAt: twoMonthsAgo.subtract(const Duration(hours: 4)),
      updatedAt: twoMonthsAgo.subtract(const Duration(hours: 4)),
    ),
  ];

  return AppSnapshot(people: people, records: records);
}
