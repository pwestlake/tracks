class WalkMetaData {
  String id;
  String name;
  final DateTime date;
  final double distance;
  final int duration;
  final double speed;
  bool checked = false;

  WalkMetaData(
      this.id, this.name, this.date, this.distance, this.duration, this.speed);
  

  WalkMetaData.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        date = DateTime.parse(json['date']),
        distance = json['distance'],
        duration = json['duration'],
        speed = json['speed'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date.toIso8601String(),
        'distance': distance,
        'duration': duration,
        'speed': speed
      };
}
