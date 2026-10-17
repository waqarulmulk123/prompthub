import 'package:flutter_test/flutter_test.dart';
import 'package:prompthub/features/creator/creator_service.dart';
import 'package:prompthub/features/community/community_screen.dart';
import 'package:image/image.dart' as image;

import 'dart:typed_data';

void main() {
  test('Brand DNA replaces related defaults and preserves unrelated edits', () {
    const dna = BrandDna('Aura Matcha', 'sage and cream', 'Nordic sunlight');
    final values = {'Surface': 'black stone', 'Product': 'old product'};
    final result = dna.apply(
      'Ad for [Product: perfume], [Palette: gold], [Lighting: studio], on [Surface: wood].',
      values,
    );
    expect(result, contains('Aura Matcha'));
    expect(result, contains('sage and cream'));
    expect(result, contains('Nordic sunlight'));
    expect(result, contains('black stone'));
    expect(result, isNot(contains('[Product:')));
    expect(values['Product'], 'old product');
    expect(
      dna.apply('A plain prompt without variables', {}),
      contains('Brand direction: Aura Matcha'),
    );
  });
  test('Remix preparation rejects non-images and emits bounded JPEG', () {
    expect(
      () => prepareRemix(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    final source = image.Image(width: 2000, height: 1000);
    final output = prepareRemix(Uint8List.fromList(image.encodePng(source)));
    final decoded = image.decodeJpg(output)!;
    expect(decoded.width, 1024);
    expect(decoded.height, 512);
    expect(output.length, lessThan(2000000));
  });
  test('Drop countdown uses server time rather than device timezone', () {
    final drop = DailyDrop({
      'day': '2026-10-17',
      'expires_at': '2026-10-18T13:00:00Z',
      'server_time': '2026-10-17T13:00:00Z',
      'claimed': false,
      'streak': 6,
      'reverse_credits': 3,
      'prompts': [],
    });
    expect(drop.remaining.inHours, inInclusiveRange(23, 24));
    expect(drop.claimed, false);
    expect(drop.credits, 3);
  });
}
