enum Category {
  video('動画'),
  music('音楽'),
  software('ソフトウェア'),
  cloud('クラウド'),
  news('ニュース・書籍'),
  game('ゲーム'),
  life('生活'),
  other('その他');

  const Category(this.label);
  final String label;
}

const intervalChoices = [1, 3, 6, 12];
const notifyChoices = <int?>[null, 0, 1, 3, 7];

String intervalLabel(int months) => switch (months) {
  1 => '毎月',
  6 => '半年ごと',
  12 => '毎年',
  _ => '$monthsか月ごと',
};

String notifyLabel(int? days) => switch (days) {
  null => 'なし',
  0 => '当日',
  _ => '$days日前',
};

class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.category,
    required this.amountYen,
    required this.intervalMonths,
    required this.firstBillingDate,
    this.notifyDaysBefore,
    this.memo = '',
  });

  factory Subscription.fromJson(Map<String, Object?> json) => Subscription(
    id: json['id']! as String,
    name: json['name']! as String,
    category: Category.values.byName(json['category']! as String),
    amountYen: json['amountYen']! as int,
    intervalMonths: json['intervalMonths']! as int,
    firstBillingDate: DateTime.parse(json['firstBillingDate']! as String),
    notifyDaysBefore: json['notifyDaysBefore'] as int?,
    memo: json['memo'] as String? ?? '',
  );

  final String id;
  final String name;
  final Category category;
  final int amountYen;
  final int intervalMonths;
  final DateTime firstBillingDate;
  final int? notifyDaysBefore;
  final String memo;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'amountYen': amountYen,
    'intervalMonths': intervalMonths,
    'firstBillingDate': firstBillingDate.toIso8601String().substring(0, 10),
    'notifyDaysBefore': notifyDaysBefore,
    'memo': memo,
  };
}
