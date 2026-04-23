import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lms_mobile/api_error_message.dart";

void main() {
  test("maps validation error payload to readable text", () {
    final ex = DioException(
      requestOptions: RequestOptions(path: "/"),
      response: Response(
        requestOptions: RequestOptions(path: "/"),
        statusCode: 400,
        data: {"error_code": "VALIDATION_ERROR", "message": "title too short"},
      ),
      type: DioExceptionType.badResponse,
    );
    final msg = readableApiError(ex, authFailure: "auth");
    expect(msg, contains("title too short"));
  });
}
