// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAccountDataAdapter extends TypeAdapter<UserAccountData> {
  @override
  final int typeId = 0;

  @override
  UserAccountData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserAccountData(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UserAccountData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAccountDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppUsageDataAdapter extends TypeAdapter<AppUsageData> {
  @override
  final int typeId = 2;

  @override
  AppUsageData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUsageData(
      appName: fields[0] as String,
      usageByType: (fields[1] as Map).cast<UsageType, int>(),
    );
  }

  @override
  void write(BinaryWriter writer, AppUsageData obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.appName)
      ..writeByte(1)
      ..write(obj.usageByType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUsageDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UsageTypeAdapter extends TypeAdapter<UsageType> {
  @override
  final int typeId = 1;

  @override
  UsageType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UsageType.playing;
      case 1:
        return UsageType.homework;
      case 2:
        return UsageType.working;
      case 3:
        return UsageType.social;
      case 4:
        return UsageType.searching;
      case 5:
        return UsageType.etc;
      default:
        return UsageType.playing;
    }
  }

  @override
  void write(BinaryWriter writer, UsageType obj) {
    switch (obj) {
      case UsageType.playing:
        writer.writeByte(0);
        break;
      case UsageType.homework:
        writer.writeByte(1);
        break;
      case UsageType.working:
        writer.writeByte(2);
        break;
      case UsageType.social:
        writer.writeByte(3);
        break;
      case UsageType.searching:
        writer.writeByte(4);
        break;
      case UsageType.etc:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsageTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
