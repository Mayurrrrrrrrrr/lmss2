class DesignationModel {
  final int id;
  final String designationName;

  DesignationModel({
    required this.id,
    required this.designationName,
  });

  factory DesignationModel.fromJson(Map<String, dynamic> json) {
    return DesignationModel(
      id: json['id'] as int,
      designationName: json['designation_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'designation_name': designationName,
    };
  }
}
