import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../errors/failure.dart';

/// Wraps a request so any problem reaches the screen as a [Failure].
/// Every repository method that calls the backend goes through it.
Future<T> guardRequest<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on Failure {
    rethrow;
  } on DioException catch (e) {
    throw failureFromDio(e);
  }
}

/// Downloads a file. Error bodies also arrive as bytes: they are decoded as JSON so the
/// backend's message (e.g. "Não há vendas em …") reaches the screen.
Future<Uint8List> downloadBytes(
  Dio dio,
  String path, {
  Map<String, dynamic>? queryParameters,
}) => guardRequest(() async {
  try {
    final response = await dio.get<List<int>>(
      path,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  } on DioException catch (e) {
    throw failureFromDio(_withJsonBody(e));
  }
});

DioException _withJsonBody(DioException e) {
  final response = e.response;
  if (response?.data case final List<int> bytes) {
    try {
      return e.copyWith(
        response: Response(
          requestOptions: response!.requestOptions,
          statusCode: response.statusCode,
          data: jsonDecode(utf8.decode(bytes)),
        ),
      );
    } on FormatException {
      return e;
    }
  }
  return e;
}

Failure failureFromDio(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return Failure.connection();
    case DioExceptionType.badResponse:
      final response = e.response;
      return Failure.fromResponse(response?.statusCode ?? 0, response?.data);
    default:
      return Failure.unexpected(statusCode: e.response?.statusCode);
  }
}
