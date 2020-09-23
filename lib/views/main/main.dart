import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:background_locator/background_locator.dart';
import 'package:background_locator/location_dto.dart';
import 'package:background_locator/settings/android_settings.dart';
import 'package:background_locator/settings/ios_settings.dart';
import 'package:background_locator/settings/locator_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong/latlong.dart' as latlong;
import 'package:location/location.dart' as loc;
import 'package:location_permissions/location_permissions.dart';
import 'package:tracks/bo/walk_metadata.dart';
import 'package:tracks/components/snapping_sheet.dart';
import 'package:tracks/service/file_service_impl.dart';
import 'package:tracks/views/edit/edit.dart';
import 'package:tracks/views/main/start_stop_state_machine.dart' as sm;
import 'package:tracks/views/main/walk_list.dart';
import 'package:tracks/views/main/walk_stats_panel.dart';

import 'location_callback_handler.dart';
import 'location_service_repository.dart';

void main() {
  runApp(App());
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Tracks",
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  loc.Location location = loc.Location();
  ReceivePort port = ReceivePort();
  List<LocationDto> route = List<LocationDto>();
  Set<Polyline> _mapRoutes = Set<Polyline>();
  bool isRunning;
  LocationDto lastLocation;
  DateTime lastTimeLocation;
  GoogleMapController mapController;
  bool fabVisible = true;
  sm.StartStopStateMachine startStopStateMachine = sm.StartStopStateMachine();
  FileServiceImpl fileService = new FileServiceImpl();
  final _colors = [Colors.red, Colors.green, Colors.black, Colors.orange];
  var _snappingSheetController = SnappingSheetController();
  num _snapPosition;

  // Timer
  int totalSeconds = 0;
  int previousSectionsSeconds = 0;
  DateTime sectionStart;
  Timer timer;

  double totalDistance = 0;
  double averageSpeed = 0;
  double altitude = 0;

  List<WalkMetaData> walks;
  List<WalkMetaData> walksReference = List<WalkMetaData>();

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  void initState() {
    super.initState();

    if (IsolateNameServer.lookupPortByName(
            LocationServiceRepository.isolateName) !=
        null) {
      IsolateNameServer.removePortNameMapping(
          LocationServiceRepository.isolateName);
    }

    IsolateNameServer.registerPortWithName(
        port.sendPort, LocationServiceRepository.isolateName);

    port.listen(
      (dynamic data) async {
        _updateRoute(data);
      },
    );
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    print('Initializing...');
    await BackgroundLocator.initialize();

    List<WalkMetaData> _walks = await fileService.getWalkItems();

    print('Initialization done');
    final _isRunning = await BackgroundLocator.isServiceRunning();
    setState(() {
      isRunning = _isRunning;
      walks = _walks;
      walksReference.addAll(walks);
    });
    print('Running ${isRunning.toString()}');
  }

  // Update the current path with the new location
  _updateRoute(dynamic data) {
    if (data is LocationDto) {
      LocationDto _location = data;
      if ((lastLocation == null ||
              route.isEmpty ||
              lastLocation.latitude != _location.latitude ||
              lastLocation.longitude != _location.longitude ||
              lastLocation.altitude != _location.altitude) &&
          !tooFast(lastLocation, _location)) {
        print('New location: ${_location.toString()}');
        route.add(_location);
        List<LatLng> _points =
            route.map((e) => LatLng(e.latitude, e.longitude)).toList();

        Polyline line = Polyline(
            polylineId: PolylineId('current'),
            color: Colors.blue,
            width: 3,
            points: _points);

        setState(() {
          _mapRoutes
              .removeWhere((element) => element.polylineId.value == 'current');
          _mapRoutes.add(line);

          totalDistance = _calculatePathDistance();
          averageSpeed = _calculateAverageSpeed();
          altitude = _location.altitude;
        });

        lastLocation = data;
      }
    }
  }

  bool tooFast(LocationDto last, LocationDto current) {
    if (last == null) {
      return false;
    }
    latlong.Distance _d =
        latlong.Distance(roundResult: false, calculator: latlong.Haversine());

    final distance = _d.as(
        latlong.LengthUnit.Mile,
        latlong.LatLng(last.latitude, last.longitude),
        latlong.LatLng(current.latitude, current.longitude));

    final time = (current.time - last.time) / 3600000; // hours
    final speed = distance / time;

    return speed > 10;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.blueGrey
    ));

    return Scaffold(
        resizeToAvoidBottomPadding: false,
        body: Stack(
          children: [
            FutureBuilder<loc.LocationData>(
                future: location.getLocation(),
                builder: (BuildContext context,
                    AsyncSnapshot<loc.LocationData> snapshot) {
                  if (snapshot.data == null) {
                    return Column();
                  }
                  return GoogleMap(
                    padding: EdgeInsets.only(top: 16.0, bottom: 72.0),
                    onMapCreated: _onMapCreated,
                    myLocationButtonEnabled: true,
                    myLocationEnabled: true,
                    polylines: _mapRoutes,
                    initialCameraPosition: CameraPosition(
                      bearing: 0.0,
                      target: LatLng(
                          snapshot.data.latitude, snapshot.data.longitude),
                      zoom: 13.5,
                    ),
                  );
                }),
            SnappingSheet(
              snappingSheetController: _snappingSheetController,
              initSnapPosition: SnapPosition(positionPixel: 0.0),
              snapPositions: [
                SnapPosition(
                    positionPixel: -105.0,
                    snappingCurve: Curves.ease,
                    snappingDuration: Duration(milliseconds: 500)),
                SnapPosition(
                    positionPixel: 0.0,
                    snappingCurve: Curves.ease,
                    snappingDuration: Duration(milliseconds: 500)),
                SnapPosition(
                    positionFactor: 1.0,
                    snappingCurve: Curves.ease,
                    snappingDuration: Duration(milliseconds: 500)),
              ],
              sheetBelow: SnappingSheetContent(
                  draggable: false,
                  child: WalkList(
                    walkStatsPanel: DetailsHeader(
                        child: WalkStatsPanel(
                      duration: totalSeconds,
                      altitude: altitude,
                      speed: averageSpeed,
                      distance: totalDistance,
                    )),
                    searchPanel: SearchHeader(child: Text('Search')),
                    list: walks,
                    selectionCallback: (index) => onWalkSelected(index),
                    editCallback: () => onEdit(),
                    deleteCallback: () => onDelete(),
                    actionsRendered: !fabVisible,
                  ),
                  heightBehavior: SnappingSheetHeight.fit()),
              grabbing: Container(
                  decoration: BoxDecoration(
                      color: Colors.blueGrey,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10.0),
                          topRight: Radius.circular(10.0))),
                  child: Column(children: [
                    AppBar(
                      title: Text('Walks'),
                      backgroundColor: Colors.blueGrey,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10.0),
                              topRight: Radius.circular(10.0))),
                      toolbarHeight: 32.0,
                      actions: [
                        // Edit
                        Visibility(
                          visible: _actionsRendered(),
                          child: IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: _editPressed()),
                        ),
                        // Delete
                        Visibility(
                          visible: _actionsRendered(),
                          child: IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: _deletePressed()),
                        ),
                        // Run
                        Visibility(
                          visible: (_snapPosition == 0 &&
                              startStopStateMachine.currentState !=
                                  startStopStateMachine.running),
                          child: IconButton(
                              icon: Icon(Icons.play_arrow),
                              onPressed: _onStart),
                        ),
                        // Pause
                        Visibility(
                          visible: (_snapPosition == 0 &&
                              startStopStateMachine.currentState ==
                                  startStopStateMachine.running),
                          child: IconButton(
                              icon: Icon(Icons.pause), onPressed: _onPause),
                        ),
                        // Stop
                        Visibility(
                          visible: isStopButtonVisible() && _snapPosition == 0,
                          child: IconButton(
                              icon: Icon(Icons.stop), onPressed: _onStop),
                        )
                      ],
                    ),
                    AnimatedSwitcher(
                        duration: Duration(milliseconds: 1000),
                        child: _getStatusOrSearchPanel())
                  ])),
              grabbingHeight: 170,
              onMove: (pos) {
                setState(() {
                  //_snapPosition = -1;
                });
              },
              onSnapEnd: () => _onSnapEnd(),
            ),
            Visibility(
                visible: isStopButtonVisible() && _snapPosition == 1,
                child: Container(
                    color: null,
                    alignment: Alignment.bottomRight,
                    padding: EdgeInsets.only(right: 16.0, bottom: 212.0),
                    child: Material(
                        shape: CircleBorder(),
                        elevation: 6,
                        color: Colors.transparent,
                        child: Ink(
                          decoration: const ShapeDecoration(
                            color: Colors.red,
                            shape: CircleBorder(),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.all(4.0),
                            icon: Icon(Icons.stop),
                            color: Colors.white,
                            onPressed: () => _onStop(),
                          ),
                        )))),
            Visibility(
                visible: (_snapPosition == 1),
                child: Container(
                    color: null,
                    alignment: Alignment.bottomRight,
                    padding: EdgeInsets.only(right: 16.0, bottom: 142.0),
                    child: getMainActionButton()))
          ],
        ));
  }

  Widget _getStatusOrSearchPanel() {
    if (_snapPosition != 2) {
      return WalkStatsPanel(
        duration: totalSeconds,
        altitude: altitude,
        speed: averageSpeed,
        distance: totalDistance,
      );
    }

    return Container(
      height: 114.0,
      color: Colors.blueGrey,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 10.0, right: 10.0),
      child: Row(
        children: [
          Icon(Icons.search),
          Expanded(
            child: TextField(
                onChanged: (value) => _search(value),
                decoration: InputDecoration(
                    labelText: 'Search', border: OutlineInputBorder())),
          )
        ],
      ),
    );
  }

  void _onSnapEnd() {
    setState(() {
      _snapPosition = _snappingSheetController.snapPositions.indexWhere(
          (element) =>
              (element.positionFactor == null &&
                  (element.positionPixel ==
                      _snappingSheetController
                          .currentSnapPosition.positionPixel)) ||
              (element.positionFactor != null &&
                  (element.positionFactor ==
                      _snappingSheetController
                          .currentSnapPosition.positionFactor)));
    });
  }

  bool _actionsRendered() {
    return _snapPosition == 2;
  }

  Function _editPressed() {
    if (_isEditEnabled()) {
      return () => onEdit();
    }

    return null;
  }

  Function _deletePressed() {
    if (_isDeleteEnabled()) {
      return () => onDelete();
    }

    return null;
  }

  // Edit is enabled if only one item is selected
  bool _isEditEnabled() {
    return _selectedCount() == 1;
  }

  bool _isDeleteEnabled() {
    return _selectedCount() >= 1;
  }

  num _selectedCount() {
    if (walks == null) {
      return 0;
    }
    num selectedCount = 0;
    walks.forEach((element) {
      if (element.checked) {
        selectedCount++;
      }
    });

    return selectedCount;
  }

  void onWalkSelected(int index) async {
    setState(() {
      walks[index].checked ^= true;
    });

    if (walks[index].checked == true) {
      List<LocationDto> _points =
          await fileService.readGPXFile(walks[index].id);
      List<LatLng> _latlng =
          _points.map((e) => LatLng(e.latitude, e.longitude)).toList();

      Polyline line = Polyline(
          polylineId: PolylineId(walks[index].id),
          color: _colors[_mapRoutes.length % _colors.length],
          width: 3,
          points: _latlng);
      setState(() {
        _mapRoutes.add(line);
      });
    } else {
      setState(() {
        _mapRoutes.removeWhere(
            (element) => element.polylineId.value == walks[index].id);
      });
    }
  }

  // Edit pressed
  void onEdit() async {
    String name = await Navigator.push(
        context, MaterialPageRoute(builder: (context) => EditWidget()));

    WalkMetaData selected = _getSelectedWalk();
    if (selected != null) {
      setState(() {
        selected.name = name;
      });

      await fileService.updateWalkFile(selected);
    }
  }

  List<WalkMetaData> _getSelectedWalks() {
    List<WalkMetaData> selected = List();
    walks.forEach((element) {
      if (element.checked) {
        selected.add(element);
      }
    });

    return selected;
  }

  WalkMetaData _getSelectedWalk() {
    WalkMetaData selected;
    walks.forEach((element) {
      if (element.checked) {
        selected = element;
      }
    });

    return selected;
  }

  // Delete pressed
  void onDelete() async {
    String result = await _showConfirmDeleteDialog();
    if (result == 'ok') {
      List<WalkMetaData> selected = _getSelectedWalks();
      bool result = await fileService.deleteReferencedItems(selected);
      if (result) {
        setState(() {
          walks.removeWhere((element) => selected.contains(element));
        });
      }
    }
  }

  // Stop the walk
  // Write the path to a file
  // Clear the path.
  // Reset the stats
  void _onStop() async {
    String result = await _showConfirmStopDialog();
    if (result == 'ok') {
      BackgroundLocator.unRegisterLocationUpdate();
      final _isRunning = await BackgroundLocator.isServiceRunning();

      WalkMetaData walkMetaData = WalkMetaData("", "Unnamed", DateTime.now(),
          totalDistance, totalSeconds, averageSpeed);
      String _id = await fileService.createWalkFile(walkMetaData);
      walkMetaData.id = _id;
      await fileService.writeGPXFile(_id, route);

      timer.cancel();
      previousSectionsSeconds = 0;
      totalDistance = 0;
      averageSpeed = 0;
      route.clear();

      setState(() {
        startStopStateMachine.nextState(startStopStateMachine.stop);
        isRunning = _isRunning;
        totalSeconds = 0;
        walks.insert(0, walkMetaData);
      });
    }
  }

  // Route started or restarted
  // Reset path and initialize start time and section counts
  void _onStart() async {
    if (await _checkLocationPermission()) {
      _startLocator();
      final _isRunning = await BackgroundLocator.isServiceRunning();

      sectionStart = DateTime.now();
      timer =
          Timer.periodic(Duration(seconds: 1), (Timer t) => _timerCallback());
      setState(() {
        startStopStateMachine.nextState(startStopStateMachine.run);
        isRunning = _isRunning;
        lastTimeLocation = null;
        lastLocation = null;
      });
    } else {
      // show error
    }
  }

  // Pause button pressed.
  // Save the current walk duration so that it can be restarted.
  // Stop the timer
  _onPause() {
    timer.cancel();
    previousSectionsSeconds = totalSeconds;

    setState(() {
      startStopStateMachine.nextState(startStopStateMachine.pause);
    });
  }

  _timerCallback() {
    setState(() {
      totalSeconds = previousSectionsSeconds +
          DateTime.now().difference(sectionStart).inSeconds;
    });
  }

  double _calculatePathDistance() {
    double _distance = 0;
    latlong.Distance _d =
        latlong.Distance(roundResult: false, calculator: latlong.Haversine());

    if (route.length > 1) {
      for (int i = 0; i < route.length - 1; i++) {
        _distance += _d.as(
            latlong.LengthUnit.Mile,
            latlong.LatLng(route[i].latitude, route[i].longitude),
            latlong.LatLng(route[i + 1].latitude, route[i + 1].longitude));
      }
    }
    return _distance;
  }

  double _calculateAverageSpeed() {
    if (totalSeconds == 0) {
      return 0;
    }

    var _avgSpeed = _calculatePathDistance() / totalSeconds; // miles /s

    return _avgSpeed * 3600; // mph
  }

  Future<bool> _checkLocationPermission() async {
    final access = await LocationPermissions().checkPermissionStatus();
    switch (access) {
      case PermissionStatus.unknown:
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
        final permission = await LocationPermissions().requestPermissions(
          permissionLevel: LocationPermissionLevel.locationAlways,
        );
        if (permission == PermissionStatus.granted) {
          return true;
        } else {
          return false;
        }
        break;
      case PermissionStatus.granted:
        return true;
        break;
      default:
        return false;
        break;
    }
  }

  void _startLocator() {
    Map<String, dynamic> data = {'countInit': 1};
    BackgroundLocator.registerLocationUpdate(LocationCallbackHandler.callback,
        initCallback: LocationCallbackHandler.initCallback,
        initDataCallback: data,
/*
        Comment initDataCallback, so service not set init variable,
        variable stay with value of last run after unRegisterLocationUpdate
 */
        disposeCallback: LocationCallbackHandler.disposeCallback,
        iosSettings: IOSSettings(
            accuracy: LocationAccuracy.NAVIGATION, distanceFilter: 0),
        autoStop: false,
        androidSettings: AndroidSettings(
            accuracy: LocationAccuracy.NAVIGATION,
            interval: 0,
            distanceFilter: 5,
            androidNotificationSettings: AndroidNotificationSettings(
                notificationChannelName: 'Location tracking',
                notificationTitle: 'Location Tracking',
                notificationMsg: 'Tracking location in background',
                notificationBigMsg:
                    'Background location is on to keep the app up-to-date with your location. This is required for main features to work properly when the app is not running.',
                notificationIcon: '',
                notificationIconColor: Colors.grey,
                notificationTapCallback:
                    LocationCallbackHandler.notificationCallback)));
  }

  bool isStopButtonVisible() {
    return fabVisible &&
        (identical(startStopStateMachine.currentState,
                startStopStateMachine.running) ||
            identical(startStopStateMachine.currentState,
                startStopStateMachine.paused));
  }

  // Main action button is either 'run' or 'pause' depending on the current
  // state
  Widget getMainActionButton() {
    if (startStopStateMachine.currentState.name == "running") {
      return ButtonTheme(
          minWidth: 100.0,
          child: RaisedButton.icon(
              onPressed: () => _onPause(),
              elevation: 6,
              label: Text('Pause'),
              icon: Icon(Icons.pause),
              color: Colors.blue,
              textColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0))));
    }

    return ButtonTheme(
        minWidth: 100.0,
        child: RaisedButton.icon(
            onPressed: () => _onStart(),
            elevation: 6,
            label: Text('Start'),
            icon: Icon(Icons.play_arrow),
            color: Colors.green,
            textColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0))));
  }

  Future<String> _showConfirmStopDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Stop walk?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Press 'Ok' to stop the walk."),
                Text('Press cancel to continue mapping.'),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop('ok');
              },
            ),
            FlatButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop('cancel');
              },
            ),
          ],
        );
      },
    );
  }

  Future<String> _showConfirmDeleteDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete selected?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Press 'Ok' to delete the selected item(s)"),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop('ok');
              },
            ),
            FlatButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop('cancel');
              },
            ),
          ],
        );
      },
    );
  }

  _search(String value) {
    List<WalkMetaData> filteredList = List<WalkMetaData>.from(walksReference);
    filteredList.removeWhere((element) => !element.name.startsWith(value));
    setState(() {
      walks = filteredList;
    });
  }
}

class OffsetFabLocation extends StandardFabLocation
    with FabEndOffsetX, FabFloatOffsetY {
  BuildContext context;

  OffsetFabLocation(this.context);

  @override
  double getOffsetY(
      ScaffoldPrelayoutGeometry scaffoldGeometry, double adjustment) {
    double screenHeight = MediaQuery.of(context).size.height;
    var padding = MediaQuery.of(context).padding;
    double offset = 0.2 * (screenHeight - padding.top - padding.bottom) - 32;

    final double directionalAdjustment =
        scaffoldGeometry.textDirection == TextDirection.ltr ? -offset : offset;
    return super.getOffsetY(scaffoldGeometry, adjustment) +
        directionalAdjustment;
  }
}

class DetailsHeader extends SliverPersistentHeaderDelegate {
  final Widget child;

  DetailsHeader({this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 114.0;

  @override
  double get minExtent => 114.0;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

class SearchHeader extends SliverPersistentHeaderDelegate {
  final Widget child;

  SearchHeader({this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 24.0;

  @override
  double get minExtent => 0.0;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
