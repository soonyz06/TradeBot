#include<Trade\Trade.mqh>
CTrade trade;
//USDJPY

enum intOptionsA{
   A1 = 1, //Short-Term
   A2 = 2, //Long-Term
   A3 = 3, //CUSTOM
};

input ulong Magic = 011;
input intOptionsA Type = A3;
input ENUM_TIMEFRAMES Timeframe = PERIOD_D1;
input double FixedLot = 0.01;
input double risk = 0.01; //Risk
double Lot;

int band = 800; //Band-Limiter
int SlPoints = 0;
//maybe 800

input string Custom =""; // 
input int t = 100; //TpPoints 
input int e = 10; //Time Exit


int TpPoints;
int time_exit;


int A = 0; //Start Time
int Z = 20; //End Time
int E = 20; //Expiration Time

//+------------------------------------------------------------------+

string today;
string yesterday;
string today2;
string yesterday2;
datetime Start;
datetime Stop;
datetime Expiration;
string Trade_Start = string(A)+":05:00"; //Start Time
string Trade_Stop = string(Z)+":00:00"; //End Time
string Trade_Expiration = string(E)+":00:00"; //Expiration Time

double bar;
double newbar;
string text;
int buyPosition;
int sellPosition;
datetime buyOpen;
datetime sellOpen;
int buyDuration;
int sellDuration;

MqlRates Price[];


//+------------------------------------------------------------------+

void OnInit(){
   trade.SetExpertMagicNumber(Magic);
   text = "S"+string(Magic);
   //bar = 0;
   yesterday = "";
   yesterday2 = "";
   ArraySetAsSeries(Price, true);
   Comment("ID: ", Magic);
   
   if(Type == 1){
      TpPoints = 400;
      //maybe 800
      time_exit = 10;
   }
   if(Type == 2){
      TpPoints = 4000;
      time_exit = 10;
   }
   if(Type==3){
      TpPoints = t;
      time_exit = e;
   }
}

//+------------------------------------------------------------------+

void OnTick(){
   //newbar = iBars(_Symbol, _Period);

   today = TimeToString(TimeCurrent(), TIME_DATE);
   today2 = TimeToString(TimeCurrent(), TIME_DATE);
   
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      
      //Entry
      if(TimeCurrent()>Start){
         CopyRates(_Symbol, Timeframe, 0, 5, Price);
         checkPositions();
         timeUpdate();
         
         kangarooEntry();
         yesterday = today;
      }
   }
   
   //Exit
   if(today2!=yesterday2){
      if(TimeCurrent()>Stop){
         checkPositions();
         timeUpdate();
         timeExit(time_exit); //both fixed
         processPosition(0);
         yesterday2=today2;
      }
   }
}

//+------------------------------------------------------------------+

void positionSize(double slpoints)
{
   if(FixedLot == 0)
   {
      string symbol = _Symbol;
      string Curr1 = StringSubstr(symbol, 0, 3);
      string Curr2 = StringSubstr(symbol, 3, 3);
      double balance;
      if (Curr2 == "USD")
      {
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = balance*risk/slpoints*100;
      }
      else if (Curr2=="JPY")
      {
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = balance*risk/slpoints*Ask2/100*100;
      }
      else 
      {
         //USDCHF etc
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = balance*risk/slpoints*Ask2*100;
         //NZDUSD etc
         if(Lot==0)
         {
            double Bid2 = NormalizeDouble(SymbolInfoDouble(Curr2+"USD", SYMBOL_BID), _Digits);
            balance = AccountInfoDouble(ACCOUNT_BALANCE);
            Lot = balance*risk/slpoints/Bid2*100;
         }
      }
      Lot = MathFloor(Lot)/100;
      
      if (Lot<0.01)
      {
         Lot = 0.01;
      }
      else if(MathIsValidNumber(Lot) == false)
      {
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = NormalizeDouble(balance*risk/slpoints, 2);
      }
      Lot = NormalizeDouble(Lot, 2);
   }
   else
   {
      Lot = FixedLot;
   }
}

void checkPositions()
{
   buyPosition = 0;
   sellPosition = 0;
   for(int i =0; i<OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      string symbol = OrderGetString(ORDER_SYMBOL);
      if (OrderSelect(ticket))
      {
         if (OrderGetInteger(ORDER_MAGIC)==Magic && symbol == _Symbol)
         {
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP)
            {
               buyPosition+=1;
            }
            else if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_STOP)
            {
               sellPosition+=1;
            }
         }
      }
   }
   for(int i =0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if (PositionSelectByTicket(ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
            {
               buyPosition+=1;
            }
            else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
            {
               sellPosition+=1;
            }
         }
      }
   }
}

void closePosition(ENUM_POSITION_TYPE type){
   for(int i =0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if (PositionSelectByTicket(ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE) == type)
            {
               trade.PositionClose(ticket);
            }
         }
      }
   }
}

void executeBuyStop(double entry){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   
   double POI;
   if(SlPoints==0){
      if(Price[2].low<Price[1].low){
         POI = Price[2].low;
      }
      else{
         POI = Price[1].low;
      }      
      int x = int((entry-POI)/_Point);
      
      
      if(x>band){
         POI = entry-band*_Point;
         positionSize(band);
      }
      else{
          positionSize(x);
      }
      
      trade.BuyStop(Lot, entry, _Symbol, POI, NULL, ORDER_TIME_SPECIFIED, Expiration, text);
   }
   else{
      positionSize(SlPoints);
      trade.BuyStop(Lot, entry, _Symbol, entry-SlPoints*_Point, NULL, ORDER_TIME_SPECIFIED, Expiration, text);
   }
}

void executeSellStop(double entry){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry) return;
   
   double POI;
   if(SlPoints==0){
      if(Price[2].high>Price[1].high){
         POI = Price[2].high;
      }
      else{
         POI = Price[1].high;
      }
      int x = int((POI-entry)/_Point);
      
      
      if(x>band){
         POI = entry+band*_Point;
         positionSize(band);
      }
      else{
          positionSize(x);
      }
      
      trade.SellStop(Lot, entry, _Symbol, POI, NULL, ORDER_TIME_SPECIFIED, Expiration, text);
   }
   else{
      positionSize(SlPoints);
      trade.SellStop(Lot, entry, _Symbol, entry+SlPoints*_Point, NULL, ORDER_TIME_SPECIFIED, Expiration, text);
   }
}

void executeBuyLimit(double entry){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask<entry) return;
   positionSize(SlPoints);
   trade.BuyLimit(Lot, entry, _Symbol, entry-SlPoints*_Point, NULL, ORDER_TIME_SPECIFIED, Expiration, text);
}

void executeSellLimit(double entry){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid>entry) return;
   positionSize(SlPoints);
   trade.SellLimit(Lot, entry, _Symbol, entry+SlPoints*_Point, NULL, ORDER_TIME_SPECIFIED, Expiration, text);
}

void executeBuy(){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   trade.Buy(FixedLot, _Symbol, Ask, Price[2].low, NULL);
}

void executeSell(){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   trade.Sell(FixedLot, _Symbol, Bid, Price[2].high, NULL);
}

void timeUpdate(){
   bool buyflag = false;
   bool sellflag = false;
   
   //Count Duration
   for(int i =0; i<PositionsTotal(); i++){
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if(PositionSelectByTicket(ticket)){
         if(PositionGetInteger(POSITION_MAGIC) == Magic && symbol == _Symbol){
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){
               buyOpen = datetime(PositionGetInteger(POSITION_TIME));
               buyDuration = iBarShift(_Symbol, PERIOD_D1, buyOpen, false) +1 ;
               buyflag = true;
            }
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){
               sellOpen = datetime(PositionGetInteger(POSITION_TIME)); 
               sellDuration = iBarShift(_Symbol, PERIOD_D1, sellOpen, false) +1;
               sellflag = true;
            }
         }
      }
   }
   
   //Reset Duration
   if(buyflag == false){
      buyDuration = 0;
   }
   if(sellflag == false){
      sellDuration = 0;
   }
   Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration);
}

void timeExit(int n){
   //Close Positon
   n+=1;
   if(buyDuration>=n){
      closePosition(POSITION_TYPE_BUY);
   }
   if(sellDuration>=n){
      closePosition(POSITION_TYPE_SELL);
   }
}

void processPosition(int n){
   if(TpPoints<0) return;
   
   if(buyDuration>n  && inProfit(POSITION_TYPE_BUY)){
      closePosition(POSITION_TYPE_BUY);
   }
   if(sellDuration>n && inProfit(POSITION_TYPE_SELL)){
      closePosition(POSITION_TYPE_SELL);
   }
}

bool inProfit(ENUM_POSITION_TYPE type)
{
   bool x = false;
   double profitMargin;
   for(int i =0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if (PositionSelectByTicket(ticket))
      {
         //Calculate Profit
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
         profitMargin = PositionGetDouble(POSITION_PRICE_CURRENT)-PositionGetDouble(POSITION_PRICE_OPEN);
         else
         profitMargin = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
         
         //Is Profit > TpPoints 
         if(PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol && PositionGetInteger(POSITION_TYPE)==type && profitMargin>TpPoints*_Point)
         {
            x =true;
         }
      }
   }
   return x;
}

void kangarooEntry(){
   //ObjectCreate(0, "Tail", OBJ_HLINE, 0, 0, 0);

   double change = (MathAbs(Price[1].close-Price[2].close))*100/Price[2].close;
   
   if(Price[2].low<Price[1].close && Price[2].low<Price[3].close && change<0.5){ //close fixed
      closePosition(POSITION_TYPE_SELL);
      if(buyPosition ==0 && sellPosition==0){
         executeBuyStop(Price[2].high); 
      }
      
      //ObjectCreate(0, "Tail", OBJ_HLINE, 0, 0, Price[2].low);
   }
   
   if(Price[2].high>Price[1].close && Price[2].high>Price[3].close && change<0.5){ //research change
      closePosition(POSITION_TYPE_BUY); 
      if(buyPosition==0 && sellPosition==0){
         executeSellStop(Price[2].low);
      }
      
      //ObjectCreate(0, "Tail", OBJ_HLINE, 0, 0, Price[2].high);
   }
}

//entry = exit?