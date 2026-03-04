import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fourmoral/models/product_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/explorePageScreen/explore_controller.dart';
import 'package:fourmoral/screens/explorePageScreen/explore_page_screen.dart';
import 'package:fourmoral/screens/product/product_view_page.dart';
import 'package:fourmoral/screens/profileScreen/profile_screen.dart';
import 'package:fourmoral/screens/searchScreen/qr_scanner.dart';
import 'package:fourmoral/screens/searchScreen/search_screen_services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../constants/colors.dart';
import '../../models/search_users_model.dart';
import '../otherProfileScreen/other_profile_screen.dart';
import '../postViewScreen/post_view_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final CollectionReference collectionUserReference = FirebaseFirestore.instance
      .collection('Users');
  final CollectionReference productCollection = FirebaseFirestore.instance
      .collection('Products');
  final exploreCnt = Get.put(ExploreCnt());

  final searchc = TextEditingController();
  List<SearchModel> searchUserDataList = [];
  bool searchUserDataFetched = false;

  List<SearchModel> filteredUserList = [];
  List<Product> productDataList = [];
  List<Product> filteredProductList = [];
  bool productDataFetched = false;

  StreamSubscription? _userDataSubscription;
  StreamSubscription? _productDataSubscription;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';
  String activeTab = 'Users'; // 'Users', 'Posts', 'Hashtags', or 'Products'
  final DatabaseReference _rtdbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> hashtagsList = [];
  List<Map<String, dynamic>> filteredHashtagsList = [];
  StreamSubscription<DatabaseEvent>? _hashtagsSubscription;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    getSavedUserData();
    getProductData();
    fetchHashtags();
    exploreCnt.getExplorePageData();
  }

  Future<void> fetchHashtags() async {
    _hashtagsSubscription = _rtdbRef.child('hashtags').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          hashtagsList =
              data.entries.map((entry) {
                return {
                  'name': entry.key,
                  'count': entry.value['count'],
                  'lastUsed': entry.value['lastUsed'],
                };
              }).toList();
          filteredHashtagsList = hashtagsList;
        });
      }
    });
  }

  Future<void> _lookupUserAndNavigate(
    String scannedMobileNumber,
    BuildContext context,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  OtherProfileScreen(mobileNumber: scannedMobileNumber),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void getSavedUserData() {
    if (!searchUserDataFetched) {
      _userDataSubscription = collectionUserReference
          .where('type', isEqualTo: "Mentor")
          .snapshots()
          .listen((snapshots) {
            searchUserDataList =
                snapshots.docs
                    .map((doc) => searchUserDataServices(doc))
                    .toList();

            if (mounted) {
              setState(() {
                searchUserDataFetched = true;
                filteredUserList = searchUserDataList;
              });
            }
          });
    }
  }

  void getProductData() {
    if (!productDataFetched) {
      _productDataSubscription = productCollection.snapshots().listen((
        snapshots,
      ) {
        productDataList =
            snapshots.docs.map((doc) => Product.fromFirestore(doc)).toList();

        if (mounted) {
          setState(() {
            productDataFetched = true;
            filteredProductList = productDataList;
          });
        }
      });
    }
  }

  void onItemChanged(String value) {
    setState(() {
      // Filter users
      filteredUserList =
          searchUserDataList.where((user) {
            return user.uniqueId.toLowerCase().contains(value.toLowerCase()) ||
                user.username.toLowerCase().contains(value.toLowerCase());
          }).toList();

      // Filter hashtags
      filteredHashtagsList =
          hashtagsList.where((hashtag) {
            return hashtag['name'].toLowerCase().contains(value.toLowerCase());
          }).toList();

      // Filter products
      filteredProductList =
          productDataList.where((product) {
            return product.name.toLowerCase().contains(value.toLowerCase()) ||
                (product.description.toLowerCase().contains(
                      value.toLowerCase(),
                    ) ??
                    false) ||
                (product.category?.toLowerCase().contains(
                      value.toLowerCase(),
                    ) ??
                    false);
          }).toList();

      // Sync with post search
      exploreCnt.syncSearchQuery(value);
    });
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) => setState(() => _isListening = false),
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _lastWords = result.recognizedWords;
              searchc.text = _lastWords;
              onItemChanged(_lastWords);
            });
          },
          listenFor: Duration(seconds: 30),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _productDataSubscription?.cancel();
    _hashtagsSubscription?.cancel();
    searchc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Search"),
        backgroundColor: blue,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Note'),
                        content: const Text(
                          'You can search here public account and saved contacts profile page, post , products ,#tags and places. \nNote. Contacts in your device can also gives you a permission to access there profile..\nExcept standard account\'s profile page and post and #tagged-post',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Okay'),
                          ),
                        ],
                      ),
                );
              },
              child: Center(child: Image.asset('assets/info.png', height: 28)),
            ),
          ),
        ],
      ),
      body: SizedBox(
        height: height,
        width: width,
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 10),
                    blurRadius: 50,
                    color: vreyDarkGrayishBlue.withOpacity(0.23),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 30,
                      width: 30,
                      child: SvgPicture.asset(
                        "assets/search.svg",
                        color: black,
                      ),
                    ),
                  ),
                  Expanded(flex: 1, child: Container()),
                  Expanded(
                    flex: 15,
                    child: TextField(
                      onChanged: onItemChanged,
                      autofocus: true,
                      controller: searchc,
                      cursorColor: Colors.black,
                      decoration: InputDecoration(
                        hintText: "Search",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _listen,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : Colors.grey,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final scannedMobileNumber = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => QrScanner()),
                        );
                        if (scannedMobileNumber != null &&
                            scannedMobileNumber.trim().isNotEmpty) {
                          await _lookupUserAndNavigate(
                            scannedMobileNumber,
                            context,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Invalid QR code or empty data"),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Scanning failed: ${e.toString()}"),
                          ),
                        );
                      }
                    },
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(Icons.qr_code_scanner),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Add tab selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabButton('All'),
                _buildTabButton('Users'),
                _buildTabButton('Posts'),
                _buildTabButton('Products'), // New tab
                _buildTabButton('Hashtags'),
              ],
            ),
            const SizedBox(height: 10),
            searchc.text != ""
                ? activeTab == 'All'
                    ? (filteredUserList.isNotEmpty ||
                            exploreCnt.filteredPostDataList.isNotEmpty ||
                            filteredProductList.isNotEmpty ||
                            filteredHashtagsList.isNotEmpty)
                        ? _buildAllResultsList(size)
                        : _buildNoResults()
                    : activeTab == 'Users'
                    ? filteredUserList.isNotEmpty
                        ? _buildUserList(size)
                        : _buildNoResults()
                    : activeTab == 'Posts'
                    ? Obx(
                      () =>
                          exploreCnt.filteredPostDataList.isNotEmpty
                              ? _buildPostList(size)
                              : _buildNoResults(),
                    )
                    : activeTab == 'Products'
                    ? filteredProductList.isNotEmpty
                        ? _buildProductList(size)
                        : _buildNoResults()
                    : filteredHashtagsList.isNotEmpty
                    ? _buildHashtagList(size)
                    : _buildNoResults()
                : _buildInitialState(size),
          ],
        ),
      ),
    );
  }

  Widget _buildProductList(Size size) {
    return Expanded(
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: filteredProductList.length,
        itemBuilder: (context, index) {
          final product = filteredProductList[index];
          return _ProductFormat(product: product);
        },
      ),
    );
  }

  Widget _buildHashtagList(Size size) {
    return Expanded(
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: filteredHashtagsList.length,
        itemBuilder: (context, index) {
          final hashtag = filteredHashtagsList[index];
          return _HashtagFormat(
            hashtag: hashtag['name'],
            count: hashtag['count'],
            lastUsed: hashtag['lastUsed'],
          );
        },
      ),
    );
  }

  Widget _buildTabButton(String title) {
    return GestureDetector(
      onTap: () {
        setState(() {
          activeTab = title;
          // Re-apply search when switching tabs
          if (searchc.text.isNotEmpty) {
            onItemChanged(searchc.text);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: activeTab == title ? blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: activeTab == title ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAllResultsList(Size size) {
    return Expanded(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          if (filteredUserList.isNotEmpty) ...[
            _buildSectionHeader('Users'),
            ...filteredUserList.map(
              (user) => _PeopleFormat(
                userObject: user,
                userphone: profileDataModel?.mobileNumber,
              ),
            ),
          ],
          if (exploreCnt.filteredPostDataList.isNotEmpty) ...[
            _buildSectionHeader('Posts'),
            ...exploreCnt.filteredPostDataList.map(
              (post) => GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostViewScreen(postId: post.key),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.urls.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: post.urls.first,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) =>
                                    Center(child: CircularProgressIndicator()),
                            errorWidget:
                                (context, url, error) => Icon(Icons.error),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.username ?? 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              post.caption ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (filteredProductList.isNotEmpty) ...[
            _buildSectionHeader('Products'),
            ...filteredProductList.map(
              (product) => _ProductFormat(product: product),
            ),
          ],
          if (filteredHashtagsList.isNotEmpty) ...[
            _buildSectionHeader('Hashtags'),
            ...filteredHashtagsList.map(
              (hashtag) => _HashtagFormat(
                hashtag: hashtag['name'],
                count: hashtag['count'],
                lastUsed: hashtag['lastUsed'],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildUserList(Size size) {
    return Expanded(
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: filteredUserList.length,
        itemBuilder: (context, index) {
          return _PeopleFormat(
            userObject: filteredUserList[index],
            userphone: profileDataModel?.mobileNumber,
          );
        },
      ),
    );
  }

  Widget _buildPostList(Size size) {
    return Expanded(
      child: Obx(
        () => ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: exploreCnt.filteredPostDataList.length,
          itemBuilder: (context, index) {
            final post = exploreCnt.filteredPostDataList[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostViewScreen(postId: post.key),
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.urls.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: post.urls.first,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) =>
                                  Center(child: CircularProgressIndicator()),
                          errorWidget:
                              (context, url, error) => Icon(Icons.error),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.username ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            post.caption ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Text(
        'No Results Found',
        style: TextStyle(
          fontFamily: 'Neue',
          fontSize: 22,
          color: black,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildInitialState(Size size) {
    return Expanded(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size.height * 0.35,
            child: Center(
              child: Text(
                'Type to Search $activeTab',
                style: TextStyle(
                  fontFamily: 'Neue',
                  fontSize: 22,
                  color: black,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Container(child: Lottie.asset("assets/search.json")),
        ],
      ),
    );
  }
}

class _PeopleFormat extends StatelessWidget {
  final SearchModel? userObject;
  final userphone;

  const _PeopleFormat({this.userObject, this.userphone});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (profileDataModel?.mobileNumber != userObject?.mobileNumber) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => OtherProfileScreen(
                    mobileNumber: userObject?.mobileNumber,
                  ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Container(
          alignment: Alignment.center,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 10),
                blurRadius: 10,
                color: vreyDarkGrayishBlue.withOpacity(0.23),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: CachedNetworkImage(
                    imageUrl: userObject?.profilePicture ?? "",
                    width: 40,
                    height: 40,
                    progressIndicatorBuilder:
                        (context, url, downloadProgress) =>
                            CircularProgressIndicator(
                              value: downloadProgress.progress,
                            ),
                    errorWidget:
                        (context, url, error) => Icon(Icons.person_2_rounded),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    userObject?.username ?? 'Unknown',
                    style: TextStyle(
                      fontFamily: 'Neue',
                      color: black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductFormat extends StatelessWidget {
  final Product product;

  const _ProductFormat({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to product detail page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductViewPage(productId: product.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 10),
                blurRadius: 10,
                color: vreyDarkGrayishBlue.withOpacity(0.23),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
                child:
                    product.imageUrls.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: product.imageUrls.first,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.shopping_bag,
                                  color: Colors.grey,
                                ),
                              ),
                        )
                        : Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[200],
                          child: Icon(Icons.shopping_bag, color: Colors.grey),
                        ),
              ),
              // Product details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontFamily: 'Neue',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      if (product.category != null)
                        Text(
                          product.category!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${product.currency} ${product.basePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: blue,
                            ),
                          ),
                          if (product.comparedAtPrice != null)
                            Text(
                              '${product.currency} ${product.comparedAtPrice!.toStringAsFixed(2)}',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HashtagFormat extends StatelessWidget {
  final String hashtag;
  final int count;
  final int lastUsed;

  const _HashtagFormat({
    required this.hashtag,
    required this.count,
    required this.lastUsed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExplorePageScreen(hashtag: hashtag),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 10),
                blurRadius: 10,
                color: vreyDarkGrayishBlue.withOpacity(0.23),
              ),
            ],
          ),
          child: ListTile(
            leading: const Icon(Icons.tag, color: Colors.blue),
            title: Text(
              '#$hashtag',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            trailing: Text(
              'Last used: ${_formatDate(lastUsed)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MMM d, y').format(date);
  }
}
