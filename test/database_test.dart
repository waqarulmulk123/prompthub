import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompthub/core/database/app_database.dart';
import 'package:prompthub/features/feed/domain/prompt_item.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());
  test(
    'public cache rejects repeated prompts and transformed copies of images',
    () async {
      final source =
          (jsonDecode(
                    File('assets/catalog/feed_page_1.json').readAsStringSync(),
                  )['prompts']
                  as List)
              .cast<Map<String, dynamic>>();
      final first = PromptItem.fromJson(source.first);
      final sameText = PromptItem.fromJson({
        ...source[1],
        'id': 'pv_duplicate_text',
        'raw_prompt': '  ${first.rawPrompt.toUpperCase()}   ',
      });
      final sameImage = PromptItem.fromJson({
        ...source[2],
        'id': 'pv_duplicate_image',
        'outputs': [
          {
            ...((source.first['outputs'] as List).first as Map),
            'image_url': '${first.outputs.first.imageUrl}&w=320',
          },
        ],
      });
      await db.cachePrompts([
        first,
        sameText,
        sameImage,
        PromptItem.fromJson(source[3]),
      ], replace: true);
      expect(await db.search(limit: 100), hasLength(2));
    },
  );
  test(
    'guest customization allowance persists and rejects the fourth edit',
    () async {
      await db.consumeGuestCustomization();
      await db.consumeGuestCustomization();
      await db.consumeGuestCustomization();
      await expectLater(db.consumeGuestCustomization(), throwsStateError);
    },
  );
  test('catalog cache supports FTS, filters, and pagination', () async {
    final data = jsonDecode(
      File('assets/catalog/feed_page_1.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final prompts = (data['prompts'] as List)
        .map((e) => PromptItem.fromJson(e as Map<String, dynamic>))
        .toList();
    await db.cachePrompts(prompts);
    expect(await db.search(limit: 5), hasLength(5));
    expect(await db.search(offset: 5, limit: 5), hasLength(5));
    expect(
      (await db.search(query: 'luxury')).map((p) => p.title),
      contains('The quiet luxury campaign'),
    );
    expect(
      (await db.search(category: 'portraits'))
          .every((p) => p.category == 'portraits'),
      isTrue,
    );
    await expectLater(db.search(query: '" OR * --'), completes);
    await db.cachePrompts(prompts);
    expect(await db.search(limit: 100), hasLength(prompts.length));
    final first = await db.search();
    final second = await db.search(offset: 10);
    final third = await db.search(offset: 20);
    expect(first, hasLength(10));
    expect(second, hasLength(10));
    expect(third, hasLength(10));
    expect(
      {...first, ...second, ...third}.map((p) => p.id).toSet(),
      hasLength(30),
    );
    expect(first.first.category, 'fashion');
    await db.cachePrompts([prompts.first], replace: true);
    expect(await db.search(), hasLength(1));
    expect(await db.findPrompt(prompts.last.id), isNull);
  });
  test('public cache strips premium text and variables', () async {
    final item = PromptItem(
      id: 'paid',
      title: 'Private',
      rawPrompt: 'secret prompt',
      category: 'product_ads',
      isProOnly: true,
      variables: const [PromptVariable(key: 'Subject', defaultValue: 'secret')],
      outputs: const [
        PromptOutput(
          model: 'flux',
          imageUrl: 'https://images.unsplash.com/preview.webp',
          aspectRatio: 1,
          blurHash: '',
        ),
      ],
    );
    await db.cachePrompts([item]);
    final cached = await db.findPrompt('paid');
    expect(cached!.rawPrompt, isEmpty);
    expect(cached.variables, isEmpty);
    expect(await db.search(query: 'secret'), isEmpty);
  });
}
