import 'package:flutter_test/flutter_test.dart';
import 'package:univesp_project/core/config/env.dart';

void main() {
  test('paths on the API get the backend address; links stay as they are', () {
    expect(
      Env.resolveUrl('/uploads/products/a1.png'),
      '${Env.apiBaseUrl}/uploads/products/a1.png',
    );
    expect(Env.resolveUrl('https://cdn.test/a.png'), 'https://cdn.test/a.png');
    expect(Env.resolveUrl('//cdn.test/a.png'), '//cdn.test/a.png');
  });
}
