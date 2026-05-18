import 'package:equatable/equatable.dart';

class AdEntity extends Equatable {
  final String id;
  final String image;
  final String whatsappLink;
  final int order;
  final DateTime expiryDate;

  const AdEntity({
    required this.id,
    required this.image,
    required this.whatsappLink,
    required this.order,
    required this.expiryDate,
  });

  @override
  List<Object?> get props => [id, image, whatsappLink, order, expiryDate];
}
