import 'dart:io';

class EventInput {
  final String title;
  final String description;
  final DateTime eventDate;
  final String? eventTime;
  final String location;
  final File? image;

  EventInput({
    required this.title,
    required this.description,
    required this.eventDate,
    this.eventTime,
    required this.location,
    this.image,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'event_time': eventTime,
      'location': location,
    };
  }
}
