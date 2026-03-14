import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

class FDCardPage extends StatefulWidget {
  @override
  _FDCardPageState createState() => _FDCardPageState();
}

class _FDCardPageState extends State<FDCardPage> {
  final List<Map<String, String>> fdCards = [
    {
      "bank": "SBM Bank",
      "logo": "assets/images/banks/sbm.png",
      "cardNumber": "**** **** **** ****",
      "details": "Minimum FD: Rs. 2,000\nCredit Limit: 90% of FD\nNo joining fee for FD above Rs. 5,000"
    },
    {
      "bank": "SBI Bank",
      "logo": "assets/images/banks/sbi.png",
      "cardNumber": "**** **** **** ****",
      "details": "Minimum FD: Rs. 25,000\n1% fuel surcharge waiver\nNo annual fee for 4 years"
    },
    {
      "bank": "ICICI Bank",
      "logo": "assets/images/banks/icici.png",
      "cardNumber": "**** **** **** ****",
      "details": "Minimum FD: Rs. 50,000\nDining offers & discounts\nNo joining or annual fee"
    },
  ];

  Map<int, bool> flipStates = {}; // Track flip state for each card

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fixed Deposit (FD) Cards')),
      body: Center(
        child: SizedBox(
          height: 250,
          child: Swiper(
            itemCount: fdCards.length,
            itemWidth: MediaQuery.of(context).size.width * 0.9,
            layout: SwiperLayout.STACK,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => setState(() {
                  flipStates[index] = !(flipStates[index] ?? false);
                }),
                child: _buildCreditCard(fdCards[index], flipStates[index] ?? false),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCreditCard(Map<String, String> cardData, bool isFlipped) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
        return AnimatedBuilder(
          animation: rotateAnim,
          builder: (context, child) {
            final isBack = rotateAnim.value > pi / 2;
            return Transform(
              transform: Matrix4.rotationY(isBack ? pi : rotateAnim.value),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: child,
        );
      },
      child: isFlipped
          ? _buildCardBack(cardData)
          : _buildCardFront(cardData),
    );
  }

  Widget _buildCardFront(Map<String, String> cardData) {
    return Container(
      key: ValueKey(true),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.blueGrey,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            cardData["logo"]!,
            height: 60,
            width: 60,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 20),
          Text(
            cardData["bank"]!,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 10),
          Text(
            cardData["cardNumber"]!,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(Map<String, String> cardData) {
    return Container(
      key: ValueKey(false),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.blueGrey.shade900,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Details",
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 10),
          Text(
            cardData["details"]!,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
