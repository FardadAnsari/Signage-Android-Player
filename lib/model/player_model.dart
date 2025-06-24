// lib/model/player_model.dart
class PlayerModel {
  String? link;

  PlayerModel();

  PlayerModel.fromJson(Map<String, dynamic> json) {
    link = json['link'];
  }
}