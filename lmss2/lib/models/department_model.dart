class DepartmentModel {
  final int id;
  final String departmentName;

  DepartmentModel({
    required this.id,
    required this.departmentName,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as int,
      departmentName: json['department_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'department_name': departmentName,
    };
  }
}
