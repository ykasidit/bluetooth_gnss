// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_gnss/main.dart';
import 'package:flutter/services.dart';

void main() {



    testWidgets('test location funcs',
                    (WidgetTester tester) async {
                        MyApp app = MyApp();
                        await tester.pumpWidget(app);

                        ScrollableTabsDemoState state = app.m_widget.m_state;

                        final AutomatedTestWidgetsFlutterBinding binding = tester.binding;
                        binding.addTime(const Duration(seconds: 3));

                        bool ret = await state.is_location_enabled();
                        print("is_location_enabled: $ret");
                        //bool ret = await state.is_location_enabled();
                  }
  );
}
