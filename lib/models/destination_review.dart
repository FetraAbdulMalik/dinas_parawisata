class DestinationReview {
  final int destinationId;
  final String userId;
  final int rating;
  final String review;
  final DateTime createdAt;

  const DestinationReview({
    required this.destinationId,
    required this.userId,
    required this.rating,
    required this.review,
    required this.createdAt,
  });

  factory DestinationReview.fromMap(Map<String, Object?> map) =>
      DestinationReview(
        destinationId: (map['destination_id'] as num).toInt(),
        userId: map['user_id'] as String,
        rating: (map['rating'] as num).toInt(),
        review: (map['review'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
