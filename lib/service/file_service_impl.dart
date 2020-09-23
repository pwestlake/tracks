import 'dart:convert';
import 'dart:io';

import 'package:background_locator/keys.dart';
import 'package:background_locator/location_dto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tracks/bo/walk_metadata.dart';
import 'package:tracks/service/file_service.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

class FileServiceImpl implements FileService {
  @override
  Future<String> createWalkFile(WalkMetaData data) async {
    DateFormat formatter = DateFormat('yyyyMMddHHmmssS');
    String id = formatter.format(DateTime.now());
    data.id = id;

    List<Future> futures = List.of({_writeMetaData(id, data)});
    await Future.wait(futures);
    return id;
  }

  @override
  Future<List<WalkMetaData>> getWalkItems() async {
    List<WalkMetaData> list = List();

    Stream<FileSystemEntity> items = await _localWalksList();

    Future<dynamic> future = items.forEach((element) {
      String path = element.path;
      WalkMetaData item = readMetaDataFile('$path/metadata.json');
      list.add(item);
    });

    List<Future> futures = List.of({future});
    await Future.wait(futures);

    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<File> _writeMetaData(String id, WalkMetaData data) async {
    final file = await _localMetaDataFile(id);
    String json = jsonEncode(data);

    return file.writeAsString(json, flush: true);
  }

  WalkMetaData readMetaDataFile(String path) {
    String json = File('$path').readAsStringSync();
    Map walkMetaDataMap = jsonDecode(json);
    return WalkMetaData.fromJson(walkMetaDataMap);
  }

  Future<File> _localMetaDataFile(String id) async {
    final dir = await _localMetaDataDirectory(id);
    String path = dir.path;
    return File('$path/metadata.json');
  }

  Future<File> _localTrackDataFile(String id) async {
    final dir = await _localMetaDataDirectory(id);
    String path = dir.path;
    return File('$path/track.xml');
  }

  Future<Directory> _localMetaDataDirectory(String id) async {
    final path = await _appDir;
    return Directory('$path/walks/$id/').create(recursive: true);
  }

  Future<String> get _appDir async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<Stream<FileSystemEntity>> _localWalksList() async {
    final path = await _appDir;
    return Directory('$path/walks/').list();
  }

  @override
  Future<WalkMetaData> updateWalkFile(WalkMetaData data) async {
    String path = await _appDir;
    String id = data.id;
    WalkMetaData walk = readMetaDataFile('$path/walks/$id/metadata.json');
    walk.name = data.name;
    await _writeMetaData(data.id, walk);

    return walk;
  }

  @override
  Future<bool> deleteReferencedItems(List<WalkMetaData> items) async {
    items.forEach((element) {
      _deleteReferencedItem(element.id);
    });

    return true;
  }

  Future<FileSystemEntity> _deleteReferencedItem(String id) async {
    Directory dir = await _localMetaDataDirectory(id);
    return dir.delete(recursive: true);
  }

  @override
  Future<File> writeGPXFile(String id, List<LocationDto> points) async {
    String gpx = _formatAsGpx(points);
    final file = await _localTrackDataFile(id);

    return file.writeAsString(gpx, flush: true);
  }

  String _formatAsGpx(List<LocationDto> points) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0"');
    builder.element('gpx', nest: () {
      builder.attribute('version', '1.1');
      builder.attribute('creator', 'Philip Westlake');
      builder.attribute(
          'xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance');
      builder.attribute('xsi:schemaLocation',
          'http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd');
      builder.element('trk', nest: () {
        builder.element('trkseg', nest: () {
          points.forEach((element) {
            builder.element('trkpt', nest: () {
              builder.attribute('lat', element.latitude);
              builder.attribute('lon', element.longitude);
              builder.element('ele', nest: element.altitude);
              builder.element('time',
                  nest:
                      DateTime.fromMillisecondsSinceEpoch(element.time.round())
                          .toIso8601String());
            });
          });
        });
      });
    });

    return builder.build().toXmlString();
  }

  @override
  Future<List<LocationDto>> readGPXFile(String id) async {
    List<LocationDto> result = List();

    String path = await _appDir;
    String gpx = await File('$path/walks/$id/track.xml').readAsString();

    XmlDocument document = XmlDocument.parse(gpx);
    Iterable<XmlElement> trkpts = document.findAllElements('trkpt');
    trkpts.forEach((element) {
      XmlAttribute lat = element.attributes
          .firstWhere((attr) => attr.name.toString() == 'lat');

      XmlAttribute lon = element.attributes
          .firstWhere((attr) => attr.name.toString() == 'lon');

      double altitude = double.parse(element.getElement('ele').innerText);
      String iso8601time = element.getElement('time').innerText;
      DateTime dateTime = DateTime.parse(iso8601time);

      Map<dynamic, dynamic> map = Map();
      map[Keys.ARG_LATITUDE] = double.parse(lat.value);
      map[Keys.ARG_LONGITUDE] = double.parse(lon.value);
      map[Keys.ARG_ALTITUDE] = altitude;
      map[Keys.ARG_TIME] = dateTime.millisecondsSinceEpoch.toDouble();

      LocationDto locationDto = LocationDto.fromJson(map);
      result.add(locationDto);
    });

    return result;
  }
}
