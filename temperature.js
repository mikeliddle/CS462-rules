angular.module('Wovyn', [])
.controller('MainCtrl', [
  '$scope','$http',
  function($scope,$http){
    $scope.profileVisible = false
    $scope.currentTemperature = 0;
    $scope.name = "";
    $scope.phone = "";
    $scope.location = "";
    $scope.temperatureThreshold = 30;
    $scope.temperatures = [];
    $scope.thresholdViolations = [];

    $scope.eci = "CKFzDy4ip6qqHEUbX7hr7f";

    var bURL = 'http://localhost:8080/sky/event/'+$scope.eci+'/eid/sensor/profile_updated';
    $scope.updateProfile = function() {
      var pURL = bURL + "?phoneNumber=" + $scope.phone + "&username=" + $scope.name;
      pURL = pURL + "&tempThreshold=" + $scope.temperatureThreshold + "&location=" + $scope.location;
      return $http.post(pURL).success(function(data){
        $scope.getAll();
        $scope.getProfile();
      });
    };

    var gURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/temperatures';
    $scope.getAll = function() {
      return $http.get(gURL).success(function(data){
        temps = data.sort(function(a, b) {
          console.log(a);
          console.log(b)
          return Date.parse(b['timestamp']) - Date.parse(a['timestamp'])
        });
        $scope.currentTemperature = temps[0];
        angular.copy(temps, $scope.temperatures)
      });
    };

    var vURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/threshold_violations';
    $scope.getViolations = function() {
      return $http.get(vURL).success(function(data){
        temps = data.sort(function(a, b) {
          console.log(a);
          console.log(b)
          return Date.parse(b['timestamp']) - Date.parse(a['timestamp'])
        });
        angular.copy(temps, $scope.thresholdViolations)
      });
    };

    var profileURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/sensor_profile/getProfile';
    $scope.getProfile = function() {
      return $http.get(profileURL).success(function(data){
        $scope.name = data['name']
        $scope.phone = data['phone']
        $scope.location = data['location']
        $scope.temperatureThreshold = data['threshold']
      });
    };

    $scope.getProfile();
    $scope.getAll();
    $scope.getViolations();
  }
]);