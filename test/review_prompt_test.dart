import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ezi_download/services/review_prompt.dart';

/// Stands in for the Play Store sheet, and counts how often it was asked for.
class _FakeReviews implements InAppReview {
  _FakeReviews({this.available = true});

  final bool available;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requests++;

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {}
}

void main() {
  late _FakeReviews reviews;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    reviews = _FakeReviews();
    ReviewPrompt.instance.reviews = reviews;
  });

  Future<void> save([int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await ReviewPrompt.instance.recordSave();
    }
  }

  test('says nothing after the first saved video', () async {
    await save();
    expect(reviews.requests, 0);
  });

  test('asks once the app has saved a second video', () async {
    await save(2);
    expect(reviews.requests, 1);
  });

  test('never asks a second time', () async {
    await save(12);
    expect(reviews.requests, 1);
  });

  test('a rating asked for in an earlier session is not asked again', () async {
    SharedPreferences.setMockInitialValues({'review_asked': true});

    await save(5);
    expect(reviews.requests, 0);
  });

  test('keeps the question for a device that can show it', () async {
    ReviewPrompt.instance.reviews = _FakeReviews(available: false);
    await save(3);

    // Nothing was shown, so nothing was spent: a later session on a device
    // with the Play Store still gets to ask.
    final asked = _FakeReviews();
    ReviewPrompt.instance.reviews = asked;
    await save();
    expect(asked.requests, 1);
  });
}
