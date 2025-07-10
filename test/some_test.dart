
import 'package:flutter/foundation.dart';
import 'package:test/test.dart';

void main() {
  test("", () async {
    final ValueNotifier<int> androidLocation = ValueNotifier(0);
    androidLocation.value = 1;
    expect(1, androidLocation.value);
  });

}