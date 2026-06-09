// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnosis_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DiagnosisResultAdapter extends TypeAdapter<DiagnosisResult> {
  @override
  final int typeId = 0;

  @override
  DiagnosisResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiagnosisResult(
      label: fields[0] as String,
      confidence: fields[1] as double,
      imagePath: fields[2] as String,
      treatmentAdvice: fields[3] as String,
      timestamp: fields[4] as DateTime?,
      diseaseName: fields[5] as String?,
      diseaseDescription: fields[6] as String?,
      severity: fields[7] as String?,
      needsValidation: fields[8] as bool,
      validationStatus: fields[9] as String?,
      rawModelLabel: fields[10] as String?,
      pendingSync: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DiagnosisResult obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.label)
      ..writeByte(1)
      ..write(obj.confidence)
      ..writeByte(2)
      ..write(obj.imagePath)
      ..writeByte(3)
      ..write(obj.treatmentAdvice)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.diseaseName)
      ..writeByte(6)
      ..write(obj.diseaseDescription)
      ..writeByte(7)
      ..write(obj.severity)
      ..writeByte(8)
      ..write(obj.needsValidation)
      ..writeByte(9)
      ..write(obj.validationStatus)
      ..writeByte(10)
      ..write(obj.rawModelLabel)
      ..writeByte(11)
      ..write(obj.pendingSync);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiagnosisResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
