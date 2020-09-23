import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracks/bo/walk_metadata.dart';

void main() {
  group("WalkMetaData tests", () {
    test('Create new entity', () {
      final entity = WalkMetaData("id", "name", DateTime.now(), 0.0, 0, 0.0);

      expect(entity.id, "id");
    });

    test('Serialize/deserialize to/from JSON', () {
      final entity = WalkMetaData("id", "name", DateTime.now(), 0.0, 0, 0.0);
      String jsonString = jsonEncode(entity);

      Map walkMetaDataMap = jsonDecode(jsonString);
      WalkMetaData deserializedEntity = WalkMetaData.fromJson(walkMetaDataMap);
      expect(entity.id, deserializedEntity.id);
    });
  });
}
