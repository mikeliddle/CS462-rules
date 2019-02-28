angular.module('Wovyn', [])
.controller('MainCtrl', [
  '$scope','$http',
  function($scope,$http){
    $scope.profileVisible = false
    $scope.currentTemperature = 0;
    $scope.name = "John Doe";
    $scope.phone = "8888888888";
    $scope.location = "Home";
    $scope.temperatureThreshold = 30;
    $scope.temperatures = [];
    $scope.thresholdViolations = [];

    $scope.eci = "";
    
    $scope.updateProfile = function() {
      var bURL = 'http://localhost:8080/sky/event/'+$scope.eci+'/eid/sensor/profile_updated';
      var pURL = bURL + "?phoneNumber=" + $scope.phone + "&username=" + $scope.name;
      pURL = pURL + "&tempThreshold=" + $scope.temperatureThreshold + "&location=" + $scope.location;
      return $http.post(pURL).success(function(data){
        $scope.getAll();
        $scope.getViolations();
        $scope.getProfile();
      });
    };

    
    $scope.getAll = function() {
      var gURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/temperatures';
      return $http.get(gURL).success(function(data){
        temps = data.sort(function(a, b) {
          console.log(a);
          console.log(b)
          return Date.parse(b['timestamp']) - Date.parse(a['timestamp'])
        });
        $scope.currentTemperature = temps[0];
        angular.copy(temps, $scope.temperatures)
        $scope.temperatures.length = Math.min($scope.temperatures.length, 10); 
      });
    };

    
    $scope.getViolations = function() {
      var vURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/threshold_violations';
      return $http.get(vURL).success(function(data){
        temps = data.sort(function(a, b) {
          console.log(a);
          console.log(b)
          return Date.parse(b['timestamp']) - Date.parse(a['timestamp'])
        });
        angular.copy(temps, $scope.thresholdViolations)
        $scope.thresholdViolations.length = Math.min($scope.thresholdViolations.length, 10); 
      });
    };

    
    $scope.getProfile = function() {
      var profileURL = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/sensor_profile/getProfile';
      return $http.get(profileURL).success(function(data){
        $scope.name = data['name']
        $scope.phone = data['phone']
        $scope.location = data['location']
        $scope.temperatureThreshold = data['threshold']
      });
    };

    $scope.runAll = function() {
      $scope.getProfile();
      $scope.getAll();
      $scope.getViolations();
    };
  }
]);