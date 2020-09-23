import 'package:flutter/material.dart';
import 'package:sprintf/sprintf.dart';

class WalkStatsPanel extends StatelessWidget {
  final int duration;
  final double distance;
  final double speed;
  final double altitude;

  WalkStatsPanel({this.duration, this.distance, this.speed, this.altitude});

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 114.0,
        padding: EdgeInsets.only(left: 10.0, right: 10.0, top: 10.0, bottom: 0.0),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: Colors.blueGrey),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
              padding: EdgeInsets.only(left: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text('Elapsed Time',
                    style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: Colors.white)),
                  Text(_formatTime(duration),
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Distance',
                    style:
                            TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: Colors.white)),
                  Text(_format(distance) + ' miles',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              )),
          Container(
              padding: EdgeInsets.only(right: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text('Average Speed',
                    style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: Colors.white)),
                  Text(_format(speed) + ' mph',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Altitude',
                    style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: Colors.white)),
                  Text(_format(altitude) + ' m',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ))
        ]),
      
    );
  }

  // Format the given number of seconds as 00:00:00
  String _formatTime(int seconds) {
    int _hours = seconds ~/ 3600;
    int _minutes = (seconds % 3600) ~/ 60;
    int _seconds = seconds % 60;
    String _time = sprintf("%02d:%02d:%02d", [_hours, _minutes, _seconds]);
    return _time;
  }

  String _format(double number) {
    return sprintf("%.2f", [number]);
  }
}
