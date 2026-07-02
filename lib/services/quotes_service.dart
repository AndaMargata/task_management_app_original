import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QuotesService {
  static Future<String> fetchQuote({List<String>? categories}) async {
    final key = (dotenv.env['API_NINJAS_KEY'] ?? '').trim();
    if (key.isEmpty) {
      throw Exception('API key missing. Add API_NINJAS_KEY in .env');
    }

    final cleanedCategories = (categories ?? const <String>[])
        .map((category) => category.trim())
        .where((category) => category.isNotEmpty)
        .toList();

    Future<http.Response> request(String path) {
      final uri = Uri.https(
        'api.api-ninjas.com',
        path,
        cleanedCategories.isEmpty
            ? null
            : <String, String>{'categories': cleanedCategories.join(',')},
      );
      return http
          .get(uri, headers: {'X-Api-Key': key})
          .timeout(const Duration(seconds: 12));
    }

    // /v2/quotes is deterministic; try random endpoint first for refresh behavior.
    var resp = await request('/v2/randomquotes');
    if (resp.statusCode == 404) {
      resp = await request('/v2/quotes');
    }

    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);

      String quote = '';
      String author = '';

      if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
        final first = data.first as Map<String, dynamic>;
        quote = (first['quote'] ?? '').toString();
        author = (first['author'] ?? '').toString();
      } else if (data is Map<String, dynamic>) {
        quote = (data['quote'] ?? '').toString();
        author = (data['author'] ?? '').toString();
      }

      if (quote.isEmpty) {
        throw Exception('Quote API returned empty data');
      }

      return '$quote\n— $author';
    } else {
      final body = resp.body.isNotEmpty ? ' | ${resp.body}' : '';
      throw Exception('Failed to fetch quote (${resp.statusCode})$body');
    }
  }
}
