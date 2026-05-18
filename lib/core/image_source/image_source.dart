abstract class ImageSource {
  Future<List<String>> pickImages();
}

class AssetImageSource implements ImageSource {
  @override
  Future<List<String>> pickImages() async {
    return [
      'assets/cars/car1.jpg',
      'assets/cars/car2.jpg',
      'assets/cars/ad_main.png',
    ];
  }
}

// class FirebaseImageSource implements ImageSource {
//   @override
//   Future<List<String>> pickImages() async {
//     // image_picker
//     // upload to storage
//     // return downloadUrls
//   }
// }

// final imageSource = AssetImageSource();
// final images = await imageSource.pickImages();
