import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompthub/core/config/app_config.dart';
import 'package:prompthub/features/feed/data/prompt_repository.dart';
import 'package:prompthub/features/feed/domain/prompt_item.dart';

void main() {
  test('managed catalog accepts only its private-storage viewing URLs', () async {
    final image = <String, dynamic>{
      'model': 'flux',
      'image_url':
          '${AppConfig.supabaseUrl}/storage/v1/object/sign/catalog-media/catalog/example.jpg?token=example',
      'aspect_ratio': 1.0,
      'blur_hash': '',
    };
    if (!AppConfig.hasSupabase) {
      expect(() => PromptOutput.fromJson(image), throwsFormatException);
      return;
    }
    expect(PromptOutput.fromJson(image).model, 'flux');
    expect(
      () => PromptOutput.fromJson({
        ...image,
        'image_url': 'https://evil.invalid/storage/v1/object/sign/catalog-media/catalog/example.jpg',
      }),
      throwsFormatException,
    );
    expect(
      () => PromptOutput.fromJson({
        ...image,
        'image_url':
            '${AppConfig.supabaseUrl}/storage/v1/object/sign/other-private-bucket/example.jpg',
      }),
      throwsFormatException,
    );
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.uri.path, '/functions/v1/catalog-content');
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'categories': {'interiors': 'Interiors'},
                'announcement': 'New original collection',
                'prompts': [
                  {
                    'id': 'pv_managed_test',
                    'title': 'Managed original',
                    'raw_prompt': 'An original interior photography prompt.',
                    'category': 'interiors',
                    'outputs': [image],
                    'variables': [],
                    'featured': true,
                  },
                ],
              },
            ),
          );
        },
      ),
    );
    final remote = PromptRemoteDatasource(dio);
    final prompts = await remote.fetch();
    expect(prompts.single.featured, isTrue);
    expect(remote.categoryLabels['interiors'], 'Interiors');
    expect(remote.announcement, 'New original collection');
    dio.close();
  });
}
