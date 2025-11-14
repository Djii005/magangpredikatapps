import 'dart:io';

class NewsInput {
  final String title;
  final String content;
  final String? summary;
  final File? image;

  NewsInput({
    required this.title,
    required this.content,
    this.summary,
    this.image,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'summary': summary,
    };
  }
}
