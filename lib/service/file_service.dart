import 'dart:io';

import 'package:background_locator/location_dto.dart';
import 'package:tracks/bo/walk_metadata.dart';

abstract class FileService {
  Future<String> createWalkFile(WalkMetaData data);
  Future<WalkMetaData> updateWalkFile(WalkMetaData data);
  Future<List<WalkMetaData>> getWalkItems();
  Future<bool> deleteReferencedItems(List<WalkMetaData> items);
  Future<File> writeGPXFile(String id, List<LocationDto> points);
  Future<List<LocationDto>> readGPXFile(String id);
}
