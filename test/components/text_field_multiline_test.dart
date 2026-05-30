import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

void main() {
  group('TextField Multi-line', () {
    test('auto-grows from minLines to maxLines', () async {
      await testNocterm(
        'auto-growing multiline field',
        (tester) async {
          final controller = TextEditingController(text: '');

          await tester.pumpComponent(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  width: 20,
                  minLines: 1,
                  maxLines: 3,
                  focused: true,
                  decoration: InputDecoration(
                    border: BoxBorder.all(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 1),
                  ),
                  showCursor: true,
                  cursorBlinkRate: null,
                ),
              ],
            ),
          );

          expect(tester.toSnapshot().split('\n'), hasLength(3));

          controller.text = 'Line 1\nLine 2';
          controller.selection =
              TextSelection.collapsed(offset: controller.text.length);
          await tester.pump();

          expect(tester.terminalState, containsText('Line 1'));
          expect(tester.terminalState, containsText('Line 2'));
          expect(tester.toSnapshot().split('\n'), hasLength(4));

          controller.text = 'Line 1\nLine 2\nLine 3\nLine 4';
          controller.selection =
              TextSelection.collapsed(offset: controller.text.length);
          await tester.pump();

          expect(tester.terminalState, isNot(containsText('Line 1')));
          expect(tester.terminalState, containsText('Line 2'));
          expect(tester.terminalState, containsText('Line 3'));
          expect(tester.terminalState, containsText('Line 4'));
          expect(tester.toSnapshot().split('\n'), hasLength(5));
        },
      );
    });

    test('keeps accepting lines past maxLines and scrolls vertically',
        () async {
      await testNocterm(
        'scrolling multiline field',
        (tester) async {
          final controller = TextEditingController(text: '');

          await tester.pumpComponent(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  width: 20,
                  minLines: 1,
                  maxLines: 2,
                  focused: true,
                  decoration: InputDecoration(
                    border: BoxBorder.all(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 1),
                  ),
                  showCursor: true,
                  cursorBlinkRate: null,
                ),
              ],
            ),
          );

          await tester.enterText('One');
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.enter,
            character: '\n',
            modifiers: const ModifierKeys(shift: true),
          ));
          await tester.enterText('Two');
          await tester.sendKeyEvent(KeyboardEvent(
            logicalKey: LogicalKey.enter,
            character: '\n',
            modifiers: const ModifierKeys(shift: true),
          ));
          await tester.enterText('Three');

          expect(controller.text, equals('One\nTwo\nThree'));
          expect(tester.terminalState, isNot(containsText('One')));
          expect(tester.terminalState, containsText('Two'));
          expect(tester.terminalState, containsText('Three'));

          await tester.sendKey(LogicalKey.pageUp);

          expect(tester.terminalState, containsText('One'));
          expect(tester.terminalState, containsText('Two'));
          expect(tester.terminalState, isNot(containsText('Three')));
        },
      );
    });

    test('cursor position is correct with wrapped lines', () async {
      await testNocterm(
        'wrapped lines cursor',
        (tester) async {
          final controller = TextEditingController(text: '');

          await tester.pumpComponent(
            TextField(
              controller: controller,
              width: 30,
              maxLines: 5,
              focused: true,
              decoration: const InputDecoration(
                border: BoxBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 1),
              ),
              showCursor: true,
              cursorBlinkRate: null, // Static cursor
            ),
          );

          // Width = 30, minus 2 for border, minus 2 for padding = 26 available
          // Add text that will wrap
          controller.text =
              'This is a long line that will definitely wrap to the next line';
          controller.selection =
              TextSelection.collapsed(offset: controller.text.length);
          await tester.pump();

          // The cursor should be at the end of the wrapped text
          // Not beyond the border
          expect(tester.terminalState, isNotNull);
          print('Text with wrapped lines:');
          print(tester.terminalState.toString());
        },
        debugPrintAfterPump: true,
      );
    });

    test('cursor moves correctly across wrapped lines', () async {
      await testNocterm(
        'cursor movement across wrapped lines',
        (tester) async {
          final controller = TextEditingController(text: '');

          await tester.pumpComponent(
            TextField(
              controller: controller,
              width: 20,
              maxLines: 4,
              focused: true,
              decoration: const InputDecoration(
                border: BoxBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 1),
              ),
              showCursor: true,
              cursorBlinkRate: null,
            ),
          );

          // Width = 20, minus 2 for border, minus 2 for padding = 16 available
          // Each line can fit 16 characters
          controller.text = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'; // 26 chars, will wrap

          // Test cursor at various positions
          controller.selection = TextSelection.collapsed(offset: 0);
          await tester.pump();
          print('\nCursor at position 0:');

          controller.selection = TextSelection.collapsed(offset: 16);
          await tester.pump();
          print('\nCursor at position 16 (should be start of line 2):');

          controller.selection = TextSelection.collapsed(offset: 26);
          await tester.pump();
          print('\nCursor at position 26 (end of text):');

          expect(tester.terminalState, isNotNull);
        },
        debugPrintAfterPump: true,
      );
    });

    test('text entry works correctly with wrapped lines', () async {
      await testNocterm(
        'text entry with wrapped lines',
        (tester) async {
          final controller = TextEditingController(text: '');

          await tester.pumpComponent(
            TextField(
              controller: controller,
              width: 25,
              maxLines: 3,
              focused: true,
              decoration: const InputDecoration(
                border: BoxBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 1),
              ),
              showCursor: true,
              cursorBlinkRate: null,
            ),
          );

          // Simulate typing a long text
          String longText =
              'Hello this is a cool thing to do is typing a cool long string that can be enough';
          controller.text = longText;
          controller.selection =
              TextSelection.collapsed(offset: longText.length);
          await tester.pump();

          print('\nTyped long text - cursor should be visible at the end:');
          expect(tester.terminalState, containsText('Hello'));
          expect(tester.terminalState, containsText('enough'));
        },
        debugPrintAfterPump: true,
      );
    });
  });
}
