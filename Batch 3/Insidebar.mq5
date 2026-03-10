#include<Trade\Trade.mqh>
CTrade trade;

input ulong Magic = 101;
input ENUM_TIMEFRAMES Timeframe = PERIOD_D1;
input double FixedLot = 0.01;
input double risk = 0.01; //Risk
double Lot;
int TpPoints = 0;
input int SlPoints = 400;

input int distance = 50; //Distance
input int TslTriggerPoints = 400;
input int TslPoints = 600;
input double Factor = 8; //Band-Limit Multiplier

input string Time; //
input int A = 4; //Start Time
int Z = 23; //Stop Time

//+------------------------------------------------------------------+

string today;
string yesterday;
string yesterday2;
datetime Start;
datetime Stop;
datetime Expiration;
string Trade_Start = string(A)+":15:00"; //Start Time
string Trade_Stop = string(Z)+":22:55"; //End Time

int bar1;
int bar2;
int newbar;
string text;
int buyPosition;
int sellPosition;
int buyDuration;
int sellDuration;
datetime buyOpen;
datetime sellOpen;
long spread;
int buyAgain;
int sellAgain;
double High;
double Low;
string suicide;
int newbarSpread =0;
int barSpread = 0;
int buyTrades;
int sellTrades;
bool flag;
bool time;

MqlRates Price[];
double ATR[];
int ATRHandler;
//+------------------------------------------------------------------+

void OnInit(){
   trade.SetExpertMagicNumber(Magic);
   text = "S"+string(Magic);
   bar1 = 0;
   bar2 = 0;
   yesterday = "";
   yesterday2 = "";
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(ATR, true);
   ATRHandler = iATR(_Symbol, PERIOD_H1, 50);
   
   ObjectCreate(0, "High", OBJ_HLINE, 0, _Period, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, _Period, 0);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   suicide = "2018.02.26";
   Comment("ID: ", Magic);
}

//+------------------------------------------------------------------+

void OnTick(){
   //newbar = iBars(_Symbol, _Period);

   today = TimeToString(TimeCurrent(), TIME_DATE);
   
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
      
      yesterday=today;
   }

   newbar= iBars(_Symbol, Timeframe);
   
   if(bar1!=newbar){    
      //Entry
      if(TimeCurrent()>Start && TimeToString(TimeCurrent(), TIME_DATE)!=suicide){
         CopyRates(_Symbol, Timeframe, 0, 3, Price);
         CopyBuffer(ATRHandler, 0, 0, 3, ATR);
         checkPositions();
         //timeUpdate();
         //timeExit(-1);
         
         //if(buyPosition+sellPosition==0){
            //time = false;
            //Comment("ID: ", Magic, "\nBuy Order Duration: ", 0, "\nSell Order Duration: ", 0);
         //}
         
         if(Price[1].high<Price[2].high && Price[1].low>Price[2].low){
            closeOrder(ORDER_TYPE_BUY_STOP, false);
            closeOrder(ORDER_TYPE_SELL_STOP, false);
            
            checkPositions();
            High = Price[2].high;
            Low = Price[2].low;
            ObjectMove(0, "High", 0, 0, High);
            ObjectMove(0, "Low", 0, 0, Low);
            if(buyPosition==0 && sellPosition==0){
               if((High-Low) < ATR[1]*Factor || Factor == 0){
                  executeBuyStop(High+distance*_Point);
                  executeSellStop(Low-distance*_Point);
                  
                  //checkPositions();
               }
            }
         }
         
         bar1=newbar;
      }
   }
   
   //Exit

   
   
   manageSpread();
   processPosition();
   
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
   buyTrades = 0;
   sellTrades = 0;
   for(int i =0; i<OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      string symbol = OrderGetString(ORDER_SYMBOL);
      if (OrderSelect(ticket))
      {
         if (OrderGetInteger(ORDER_MAGIC)==Magic && symbol == _Symbol)
         {
            if((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) || (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT))
            {
               buyPosition+=1;
            }
            else if((OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_STOP) || (OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_LIMIT))
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
               buyTrades+=1;
            }
            else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
            {
               sellPosition+=1;
               sellTrades+=1;
            }
         }
      }
   }
}

void closePosition(ENUM_POSITION_TYPE type){
   int total = PositionsTotal();
   int closed = 0;
   int i;
   
   for(int j =0; j<total; j++)
   {
      i = j-closed;      
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if (PositionSelectByTicket(ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE) == type)
            {
               trade.PositionClose(ticket);
               closed +=1;
            }
         }
      }
   }
}
void executeBuyStop(double entry){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   positionSize(SlPoints);
   
   double sl;
   double tp;
   if(SlPoints<=0) sl = (Price[2].high+Price[2].low)/2;
   else sl = entry-SlPoints*_Point;
   
   if(TpPoints<=0) tp = NULL;
   else tp = entry+TpPoints*_Point;
   
   trade.BuyStop(Lot, entry, _Symbol, sl, tp, NULL, 0, text);
}

void executeSellStop(double entry){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry) return;
   positionSize(SlPoints);
   
   double sl;
   double tp;
   if(SlPoints<=0) sl = (Price[2].high+Price[2].low)/2;
   else sl = entry+SlPoints*_Point;
   
   if(TpPoints<=0) tp = NULL;
   else tp = entry-TpPoints*_Point;
   
   trade.SellStop(Lot, entry, _Symbol, sl, tp, NULL, 0, text);
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
   positionSize(SlPoints);
   double sl;
   double tp;
   if(SlPoints<=0) sl = NULL;
   else sl = Ask-SlPoints*_Point;   
   if(TpPoints<=0) tp = NULL;
   else tp = Ask+TpPoints*_Point;
   
   trade.Buy(Lot, _Symbol, Ask, sl, tp, text);
}

void executeSell(){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   positionSize(SlPoints);
   double sl;
   double tp;
   if(SlPoints<=0) sl = NULL;
   else sl = Bid+SlPoints*_Point;
   if(TpPoints<=0) tp = NULL;
   else tp = Bid-TpPoints*_Point;
   
   trade.Sell(Lot, _Symbol, Bid, sl, tp, text);
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

void timeUpdate(){

   if(time==false) return;

   bool buyflag = false;
   bool sellflag = false;
   
   if(OrdersTotal()==0) return;
   int total = OrdersTotal();
   int closed = 0;
   int i;
   
   for(int j =0; j<total; j++)
   {  
      i = j-closed;
      ulong ticket = OrderGetTicket(i);
      if (OrderSelect(ticket))
      {
         string symbol = OrderGetString(ORDER_SYMBOL);
         if (OrderGetInteger(ORDER_MAGIC)==Magic && symbol == _Symbol)
         {
            if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_BUY_STOP){
               buyOpen = datetime(OrderGetInteger(ORDER_TIME_SETUP));
               buyDuration = iBarShift(_Symbol, Timeframe, buyOpen, false);
               buyflag = true;
            }
            if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_STOP){
               sellOpen = datetime(OrderGetInteger(ORDER_TIME_SETUP));
               sellDuration = iBarShift(_Symbol, Timeframe, sellOpen, false);
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
   Comment("ID: ", Magic, "\nBuy Order Duration: ", buyDuration, "\nSell Order Duration: ", sellDuration);
}

void timeExit(int n){
   if(time==false) return;
   
   //Close Order
   if(buyDuration>=n){
      closeOrder(ORDER_TYPE_BUY_STOP, false);
      time = false;
      Comment("ID: ", Magic, "\nBuy Order Duration: ", 0, "\nSell Order Duration: ", 0);
   }
   if(sellDuration>=n){
      closeOrder(ORDER_TYPE_SELL_STOP, false);
      time = false;
      Comment("ID: ", Magic, "\nBuy Order Duration: ", 0, "\nSell Order Duration: ", 0);
   }
}

void snailExit(int n){
   if(TpPoints<0) return;
   
   if(buyDuration>n  && inProfit(POSITION_TYPE_BUY)){
      closePosition(POSITION_TYPE_BUY);
   }
   if(sellDuration>n && inProfit(POSITION_TYPE_SELL)){
      closePosition(POSITION_TYPE_SELL);
   }
}

void closeOrder(ENUM_ORDER_TYPE type, bool toggle)
{  
   if(OrdersTotal()==0) return;
   int total = OrdersTotal();
   int closed = 0;
   int i;
   
   for(int j =0; j<total; j++)
   {  
      i = j-closed;
      ulong ticket = OrderGetTicket(i);
      if (OrderSelect(ticket))
      {
         string symbol = OrderGetString(ORDER_SYMBOL);
         if (OrderGetInteger(ORDER_MAGIC)==Magic && symbol == _Symbol && OrderGetInteger(ORDER_TYPE)==type)
         {
            if(toggle==true){
               if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_BUY_STOP){
                  buyAgain +=1;
               }
               if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_STOP){
                  sellAgain +=1;
               }
            }
            trade.OrderDelete(ticket);
         }
      }
   }
   
   if(toggle==false){
      buyAgain=0;
      sellAgain=0;
   }
}

void processPosition()
{
   if(PositionsTotal()==0) return; 
   for(int i =0; i<PositionsTotal(); i++){
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket)){
         if (PositionGetInteger(POSITION_MAGIC)==Magic && PositionGetString(POSITION_SYMBOL)== _Symbol){
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
            {
               double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
               if(Bid>=PositionGetDouble(POSITION_PRICE_OPEN)+TslTriggerPoints*_Point)
               {
                  double Sl = NormalizeDouble(Bid-TslPoints*_Point, _Digits);
                  if(Sl>PositionGetDouble(POSITION_SL))
                  {
                     trade.PositionModify(ticket, Sl, PositionGetDouble(POSITION_TP));
                  }
               }
            }
            else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
            {
               double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
               if(Ask<=PositionGetDouble(POSITION_PRICE_OPEN)-TslTriggerPoints*_Point)
               {
                  double Sl = NormalizeDouble(Ask+TslPoints*_Point, _Digits);
                  if(Sl<PositionGetDouble(POSITION_SL))
                  {
                     trade.PositionModify(ticket, Sl, PositionGetDouble(POSITION_TP));
                  }
               }               
            }
         }
      }
   }
}

void manageSpread(){

   spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   if(spread>300){
      closeOrder(ORDER_TYPE_BUY_STOP, true);
      closeOrder(ORDER_TYPE_SELL_STOP, true);
      
   }
   
   //Comment(buyAgain, sellAgain);
   //Print(spread);
      
   newbarSpread = iBars(_Symbol, PERIOD_H1); 
   
   if(barSpread!=newbarSpread){
      if(spread<100){ //Don't Change
         if(buyAgain>0 && buyPosition==0){
            executeBuyStop(High+distance*_Point);
            buyAgain=0;
         }
         if(sellAgain>0 && sellPosition==0){
            executeSellStop(Low-distance*_Point);
            sellAgain=0;
         }
      }
      barSpread=newbarSpread;
   }
   
   checkPositions();
   if(buyTrades+sellTrades==0){
      flag = true;
   }
   
   if(PositionsTotal()==0) return;
   
   if(buyTrades+sellTrades>0 && flag == true){
      calibrate();
      time = true;
      //closeOrder(ORDER_TYPE_BUY_STOP, false);
      //closeOrder(ORDER_TYPE_SELL_STOP, false);
      flag = false;
   }
   
}

void calibrate()
{
   if(PositionsTotal()==0) return; 
   for(int i =0; i<PositionsTotal(); i++){
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket)){
         if (PositionGetInteger(POSITION_MAGIC)==Magic && PositionGetString(POSITION_SYMBOL)== _Symbol){
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
            {
               double Sl = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN)-SlPoints*_Point, _Digits);
               if(Sl>PositionGetDouble(POSITION_SL))
               {
                  trade.PositionModify(ticket, Sl, PositionGetDouble(POSITION_TP));
               }
            }
            else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
            {
               double Sl = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN)+SlPoints*_Point, _Digits);
               if(Sl<PositionGetDouble(POSITION_SL))
               {
                  trade.PositionModify(ticket, Sl, PositionGetDouble(POSITION_TP));
               }            
            }
         }
      }
   }
}

//One trade (tick) price above high when buy stop placed so winning trade missed out on as buy stop not placed (compared to OHLC) 11.18 i think
//Another (tick) price closed down so open at different price (calibration reduce loss) (compared to OHLC where price did not open below and trigger sell stop) 12.19
//6.22 and 7.04 price spread jump :)
//one less win each, 2 more trades recent?