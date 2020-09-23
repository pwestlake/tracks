import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/bo/walk_metadata.dart';
import 'package:tracks/service/file_service_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Create a temporary directory.
    final directory = await Directory.systemTemp.createTemp();

    // Mock out the MethodChannel for the path_provider plugin.
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      // If you're getting the apps documents directory, return the path to the
      // temp directory on the test environment instead.
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return directory.path;
      }
      return null;
    });
  });

  group("FileServiceImpl tests", () {
    test('Create new WalkMetaData item', () async{
      final entity = WalkMetaData("", "name", DateTime.now(), 0.0, 0, 0.0);
      FileServiceImpl fileService = FileServiceImpl();
      await fileService.createWalkFile(entity);

      List<WalkMetaData> list = await fileService.getWalkItems();
      expect(list.length, 1);
    
    });
  });
}
