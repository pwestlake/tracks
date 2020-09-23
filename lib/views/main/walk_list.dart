import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';
import 'package:tracks/bo/walk_metadata.dart';

class WalkList extends StatelessWidget {
  final SliverPersistentHeaderDelegate walkStatsPanel;
  final SliverPersistentHeaderDelegate searchPanel;
  final List<WalkMetaData> list;
  final void Function(int index) selectionCallback;
  final void Function() editCallback;
  final void Function() deleteCallback;
  final bool actionsRendered;

  WalkList(
      {@required this.walkStatsPanel,
      @required this.searchPanel,
      @required this.list,
      @required this.selectionCallback,
      @required this.editCallback,
      @required this.deleteCallback,
      this.actionsRendered});

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white,
        child: CustomScrollView(
          //controller: controller,
          slivers: <Widget>[
            // SliverAppBar(
            //   shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.only(
            //           topLeft: Radius.circular(10.0),
            //           topRight: Radius.circular(10.0))),
            //   title: Text("Walks"),
            //   backgroundColor: Colors.blueGrey,
            //   automaticallyImplyLeading: false,
            //   primary: false,
            //   floating: true,
            //   pinned: true,
            //   actions: [
            //     Visibility(
            //       visible: _actionsRendered(),
            //       child: IconButton(
            //           icon: Icon(Icons.edit), onPressed: _editPressed()),
            //     ),
            //     Visibility(
            //       visible: _actionsRendered(),
            //       child: IconButton(
            //           icon: Icon(Icons.delete), onPressed: _deletePressed()),
            //     )
            //   ],
            // ),
            // SliverPersistentHeader(
            //     floating: false,
            //     pinned: false,
            //     delegate: walkStatsPanel),
            // SliverPersistentHeader(
            //     floating: true,
            //     pinned: false,
            //     delegate: searchPanel),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, idx) => Card(
                    child: Container(
                        padding: EdgeInsets.only(right: 10.0),
                        color: Colors.white,
                        child: Column(children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: list[idx].checked == null
                                          ? false
                                          : list[idx].checked,
                                      onChanged: (value) =>
                                          selectionCallback(idx),
                                    ),
                                    Text(_distance(idx))
                                  ],
                                ),
                                Text(_dateFormat(list[idx].date))
                              ]),
                          ListTile(
                            title: Text(list[idx].name == null
                                ? 'Unnamed'
                                : list[idx].name),
                            subtitle: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_duration(idx)),
                                Text(_avgSpeed(idx))
                              ],
                            ),
                          ),
                        ]))),
                childCount: list == null ? 0 : list.length,
              ),
            )
          ],
        ));
  }

  String _distance(int idx) {
    return sprintf("%.2f miles", [list[idx].distance]);
  }

  String _duration(int idx) {
    return sprintf("Duration: %s", [_formatTime(list[idx].duration)]);
  }

  String _formatTime(int seconds) {
    int _hours = seconds ~/ 3600;
    int _minutes = (seconds % 3600) ~/ 60;
    int _seconds = seconds % 60;
    String _time = sprintf("%02d:%02d:%02d", [_hours, _minutes, _seconds]);
    return _time;
  }

  String _avgSpeed(int idx) {
    return sprintf("Avg Speed: %.2f mph", [list[idx].speed]);
  }

  bool _actionsRendered() {
    return actionsRendered;
  }

  Function() _editPressed() {
    if (_isEditEnabled()) {
      return editCallback;
    }

    return null;
  }

  Function() _deletePressed() {
    if (_isDeleteEnabled()) {
      return deleteCallback;
    }

    return null;
  }

  String _dateFormat(DateTime date) {
    DateFormat pattern = DateFormat("dd MMM yyyy");
    return pattern.format(date);
  }

  // Edit is enabled if only one item is selected
  bool _isEditEnabled() {
    return _selectedCount() == 1;
  }

  bool _isDeleteEnabled() {
    return _selectedCount() >= 1;
  }

  num _selectedCount() {
    if (list == null) {
      return 0;
    }
    num selectedCount = 0;
    list.forEach((element) {
      if (element.checked) {
        selectedCount++;
      }
    });

    return selectedCount;
  }
}


