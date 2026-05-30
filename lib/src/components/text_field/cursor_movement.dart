import 'package:characters/characters.dart';
import '../../text/selection_utils.dart' as selection_utils;
import '../../text/text_layout_engine.dart';
import '../../utils/unicode_width.dart';

/// Helper class for cursor movement calculations based on text layout
class CursorMovement {
  /// Information about a cursor position in the laid out text
  static CursorPosition getCursorPosition({
    required TextLayoutResult layoutResult,
    required String text,
    required int cursorOffset,
  }) {
    if (layoutResult.lines.isEmpty) {
      return CursorPosition(
        line: 0,
        column: 0,
        visualColumn: 0,
        lineStartOffset: 0,
        lineEndOffset: 0,
      );
    }

    final cursor = cursorOffset.clamp(0, text.length);
    final lineStarts =
        selection_utils.lineStartOffsets(text, layoutResult.lines);

    for (int i = 0; i < layoutResult.lines.length; i++) {
      final line = layoutResult.lines[i];
      final lineStartOffset = lineStarts[i];
      final lineEndOffset = lineStartOffset + line.length;
      final nextLineStartOffset =
          i + 1 < lineStarts.length ? lineStarts[i + 1] : text.length + 1;

      if (cursor < nextLineStartOffset || i == layoutResult.lines.length - 1) {
        final positionInLine = (cursor - lineStartOffset).clamp(0, line.length);
        final textBeforeCursor =
            positionInLine > 0 ? line.substring(0, positionInLine) : '';
        final visualColumn = UnicodeWidth.stringWidth(textBeforeCursor);

        return CursorPosition(
          line: i,
          column: positionInLine,
          visualColumn: visualColumn,
          lineStartOffset: lineStartOffset,
          lineEndOffset: lineEndOffset,
          actualLineIndex: _actualLineIndexForOffset(text, lineStartOffset),
        );
      }
    }

    // Cursor is at the very end
    final lastLine = layoutResult.lines.last;
    final lastLineStart = lineStarts.last;
    return CursorPosition(
      line: layoutResult.lines.length - 1,
      column: lastLine.length,
      visualColumn: UnicodeWidth.stringWidth(lastLine),
      lineStartOffset: lastLineStart,
      lineEndOffset: lastLineStart + lastLine.length,
      actualLineIndex: _actualLineIndexForOffset(text, lastLineStart),
    );
  }

  /// Move cursor horizontally by one grapheme cluster
  static int moveCursorHorizontally({
    required String text,
    required int currentOffset,
    required int direction,
  }) {
    if (direction == 0) return currentOffset;

    final graphemes = text.characters.toList();
    if (graphemes.isEmpty) return 0;

    // Find current position in grapheme clusters
    int currentGraphemeIndex = 0;
    int charCount = 0;

    for (int i = 0; i < graphemes.length; i++) {
      if (charCount >= currentOffset) {
        currentGraphemeIndex = i;
        break;
      }
      charCount += graphemes[i].length;
      if (i == graphemes.length - 1) {
        currentGraphemeIndex = graphemes.length;
      }
    }

    // Move by one grapheme cluster
    final newGraphemeIndex =
        (currentGraphemeIndex + direction).clamp(0, graphemes.length);

    // Calculate new character offset
    int newOffset = 0;
    for (int i = 0; i < newGraphemeIndex && i < graphemes.length; i++) {
      newOffset += graphemes[i].length;
    }

    return newOffset;
  }

  /// Move cursor vertically maintaining visual column position
  static int moveCursorVertically({
    required TextLayoutResult layoutResult,
    required String text,
    required int currentOffset,
    required int direction,
    required int targetVisualColumn,
  }) {
    if (layoutResult.lines.isEmpty || direction == 0) return currentOffset;

    final currentPos = getCursorPosition(
      layoutResult: layoutResult,
      text: text,
      cursorOffset: currentOffset,
    );

    final targetLine =
        (currentPos.line + direction).clamp(0, layoutResult.lines.length - 1);
    if (targetLine == currentPos.line) return currentOffset;

    // Find the new cursor position on the target line
    final newLine = layoutResult.lines[targetLine];

    final lineStarts = selection_utils.lineStartOffsets(
      text,
      layoutResult.lines,
    );
    final newLineStartOffset = lineStarts[targetLine];

    // Find position in new line that matches target visual column
    int columnInNewLine = 0;
    int visualColumnCount = 0;

    for (final char in newLine.characters) {
      final charWidth = UnicodeWidth.stringWidth(char);
      if (visualColumnCount + charWidth > targetVisualColumn) {
        // We've gone past the target column
        break;
      }
      visualColumnCount += charWidth;
      columnInNewLine += char.length;
    }

    return newLineStartOffset + columnInNewLine;
  }

  static int _actualLineIndexForOffset(String text, int offset) {
    final end = offset.clamp(0, text.length);
    var line = 0;
    for (var i = 0; i < end; i++) {
      if (text.codeUnitAt(i) == 0x0a) {
        line++;
      }
    }
    return line;
  }

  /// Move cursor by word
  static int moveCursorByWord({
    required String text,
    required int currentOffset,
    required int direction,
  }) {
    if (direction == 0 || text.isEmpty) return currentOffset;

    int offset = currentOffset;

    if (direction < 0) {
      // Move backward by word
      if (offset == 0) return 0;

      // Skip spaces backward
      while (offset > 0 && _isWordBoundary(text[offset - 1])) {
        offset--;
      }

      // Skip word characters backward
      while (offset > 0 && !_isWordBoundary(text[offset - 1])) {
        offset--;
      }
    } else {
      // Move forward by word
      if (offset >= text.length) return text.length;

      // Skip current word forward
      while (offset < text.length && !_isWordBoundary(text[offset])) {
        offset++;
      }

      // Skip spaces forward
      while (offset < text.length && _isWordBoundary(text[offset])) {
        offset++;
      }
    }

    return offset;
  }

  /// Move cursor to start of current line
  static int moveCursorToLineStart({
    required TextLayoutResult layoutResult,
    required String text,
    required int currentOffset,
  }) {
    final pos = getCursorPosition(
      layoutResult: layoutResult,
      text: text,
      cursorOffset: currentOffset,
    );

    return pos.lineStartOffset;
  }

  /// Move cursor to end of current line
  static int moveCursorToLineEnd({
    required TextLayoutResult layoutResult,
    required String text,
    required int currentOffset,
  }) {
    final pos = getCursorPosition(
      layoutResult: layoutResult,
      text: text,
      cursorOffset: currentOffset,
    );

    return pos.lineEndOffset;
  }

  static bool _isWordBoundary(String char) {
    return char == ' ' ||
        char == '\t' ||
        char == '\n' ||
        char == '\r' ||
        char == '.' ||
        char == ',' ||
        char == ';' ||
        char == ':' ||
        char == '!' ||
        char == '?' ||
        char == '(' ||
        char == ')' ||
        char == '[' ||
        char == ']' ||
        char == '{' ||
        char == '}' ||
        char == '"' ||
        char == "'" ||
        char == '/' ||
        char == '\\';
  }
}

/// Information about a cursor position in laid out text
class CursorPosition {
  final int line; // Line index in the layout result
  final int column; // Character column within the line
  final int visualColumn; // Visual column accounting for Unicode width
  final int lineStartOffset; // Character offset of line start in original text
  final int lineEndOffset; // Character offset of line end in original text
  final int actualLineIndex; // Actual line index (counting only real newlines)

  const CursorPosition({
    required this.line,
    required this.column,
    required this.visualColumn,
    required this.lineStartOffset,
    required this.lineEndOffset,
    this.actualLineIndex = 0,
  });
}
