import 'package:dio/dio.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8787',
);
const googleClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class Api {
  final Dio dio;
  Api({Dio? client})
    : dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 45),
              sendTimeout: const Duration(seconds: 45),
            ),
          );
  String? token;
  Options get options =>
      Options(headers: token == null ? {} : {'Authorization': 'Bearer $token'});
  Future<Map<String, dynamic>> get(String path) async =>
      Map<String, dynamic>.from(
        (await dio.get(path, options: options)).data as Map,
      );
  Future<Map<String, dynamic>> post(String path, [Object? data]) async =>
      Map<String, dynamic>.from(
        (await dio.post(path, data: data, options: options)).data as Map,
      );
  Future<Map<String, dynamic>> put(String path, Object data) async =>
      Map<String, dynamic>.from(
        (await dio.put(path, data: data, options: options)).data as Map,
      );
  Future<void> delete(String path) async {
    await dio.delete(path, options: options);
  }

  String url(String value) =>
      value.startsWith('/') ? '${dio.options.baseUrl}$value' : value;
  Map<String, String> get headers =>
      token == null ? {} : {'Authorization': 'Bearer $token'};
}

String errorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      return data['error']['message'].toString();
    }
    return '通信できませんでした。接続を確認して再度お試しください';
  }
  return e.toString().replaceFirst('Exception: ', '');
}
