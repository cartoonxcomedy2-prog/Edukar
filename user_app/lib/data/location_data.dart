class LocationData {
  static const List<String> provinces = ['Sindh', 'Punjab', 'KPK', 'Balochistan', 'Gilgit Baltistan', 'Azad Kashmir'];
  static const List<String> cities = ['Karachi', 'Hyderabad', 'Sukkur', 'Larkana', 'Mirpurkhas', 'Nawabshah'];
  static const List<String> genders = ['Male', 'Female', 'Other'];

  static List<String> getStates(String country) {
    if (country == 'Pakistan') return provinces;
    return [];
  }

  static List<String> getCities(String country, String state) {
    if (country == 'Pakistan') {
      // In a real app, this would be a map, for now return static cities for Sindh
      if (state == 'Sindh') return cities;
      return ['General City'];
    }
    return [];
  }
}
