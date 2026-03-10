#include<Trade\Trade.mqh>
CTrade trade;
//GBPJPY

input ulong Magic = 010;
input ENUM_TIMEFRAMES Timeframe = PERIOD_D1;
input double FixedRisk = 0.01;
input double VariableRisk = 0;
input double MinLot = 0.01;
double Lot;
//input int TpPoints = 3000; 
//input int SlPoints = 1500;
//input int break_even = 2100; //Break-even
input double TpATR = 0;
input double SlATR = 1;
input double BKAtr = -1;
input int time_exit = 20; //Time Exit
//10 or 30
input int lookback = 20; //Bars Lookback
double ret = 0.1; //Retracement

input int A = 0; //Start Time
input int Z = 20; //End Time
int E = 18; //Expiration Time

//+------------------------------------------------------------------+

string today;
string yesterday;
string today2;
string yesterday2;
datetime Start;
datetime Stop;
datetime Expiration;
string Trade_Start= string(A)+":45:00"; 
string Trade_Stop = string(Z)+":35:00"; 
string Trade_Expiration = string(E)+":00:00"; 

double bar;
double newbar;
string text;
int buyPosition;
int sellPosition;
int buyDuration;
int sellDuration;
datetime buyOpen;
datetime sellOpen;
int TslTriggerPoints;
int TslPoints;
double initial_balance;

MqlRates Price[];
double High[];
double Low[];
double Highest;
double Lowest;
double Ask;
double Bid;
double oldHigh;
double oldLow;
double ATR[];
int ATRHandler;
double MA[];
int MAHandler;



//+------------------------------------------------------------------+



void OnInit(){
   trade.SetExpertMagicNumber(Magic);
   text = "S"+string(Magic);
   //bar = 0;
   yesterday = "";
   yesterday2 = "";
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   ArraySetAsSeries(ATR, true);
   ArraySetAsSeries(MA, true);
   ATRHandler = iATR(_Symbol, PERIOD_D1, 50);
   MAHandler = iMA(_Symbol, PERIOD_D1, lookback, 0, MODE_SMA, PRICE_CLOSE);
   
   initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ObjectCreate(0, "Max", OBJ_HLINE, 0, _Period, 0);
   ObjectSetInteger(0, "Max", OBJPROP_COLOR, clrWhite);
   ObjectCreate(0, "Min", OBJ_HLINE, 0, _Period, 0);
   ObjectSetInteger(0, "Min", OBJPROP_COLOR, clrWhite);
   Comment("ID: ", Magic);
   oldHigh = 0;
   oldLow = 0;
}

//+------------------------------------------------------------------+

void OnTick(){
   //newbar = iBars(_Symbol, _Period);

   today = TimeToString(TimeCurrent(), TIME_DATE);
   
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      CopyBuffer(ATRHandler, 0, 0, 3, ATR);
      CopyBuffer(MAHandler, 0, 0, 3, MA);
      
      //Entry
      if(TimeCurrent()>Start && TimeCurrent()<Stop){
         CopyRates(_Symbol, Timeframe, 0, 3, Price);
         range(lookback);
         checkPositions();
         timeUpdate();
         
//         if(buyDuration>0 && Price[1].close<MA[1])
//         closePosition(POSITION_TYPE_BUY);
//         
//         if(sellDuration>0 && Price[1].close>MA[1])
//         closePosition(POSITION_TYPE_SELL);
         
         if(buyPosition==0)
         executeBuyStop(Highest);
         if(sellPosition==0)
         executeSellStop(Lowest);
         
         yesterday = today;
      }
   }
   
   //Exit
   if(today!=yesterday2){
      if(TimeCurrent()>Stop){
         checkPositions();
         timeUpdate();
         timeExit(time_exit);
         //processPosition();
         snailExit(0);
         yesterday2=today;
      }
   }
}

//+------------------------------------------------------------------+

void PositionSize(){
   if(VariableRisk<=0 && FixedRisk<=0){
      Lot = MinLot;
   }
   else if(MinLot<0.1)
   {
      double slpoints = (ATR[1]*SlATR)/_Point;
      string Curr1 = StringSubstr(_Symbol, 0, 3);
      string Curr2 = StringSubstr(_Symbol, 3, 3);
      if(FixedRisk>0){
         Lot = initial_balance*FixedRisk/slpoints;
      }
      else{
         int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
         Lot = _rounded_balance*VariableRisk/slpoints;
      }
      if (Curr2 == "USD"){
         
      }
      else if(Curr2=="JPY"){
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         Lot = Lot*Ask2/100;
      }
      else{
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         double Bid2 = NormalizeDouble(SymbolInfoDouble(Curr2+"USD", SYMBOL_BID), _Digits);
         Lot = Lot*Ask2;
         if(Lot==0)
            Lot = Lot/Bid2;
      }
      Lot = MathRound(Lot/MinLot)*MinLot;
   }
   else{
      if(FixedRisk>0){
         Lot = MathRound((initial_balance*FixedRisk)/(ATR[1]*SlATR)/MinLot)*MinLot;
      }
      else{
         int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
         Lot = MathRound((_rounded_balance*VariableRisk)/(ATR[1]*SlATR)/MinLot)*MinLot;
      }
   }
   if(Lot<MinLot) Lot=MinLot;
   if(Lot>1000) Lot=1000;
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

void closeOrder(ENUM_ORDER_TYPE type)
{
   for (int i=OrdersTotal()-1; i>=0; i--)
   {  
      ulong ticket = OrderGetTicket(i);
      if (OrderSelect(ticket))
      {
         string symbol = OrderGetString(ORDER_SYMBOL);
         if (OrderGetInteger(ORDER_MAGIC)==Magic && symbol == _Symbol && OrderGetInteger(ORDER_TYPE)==type)
         {
            trade.OrderDelete(ticket);
         }
      }
   }
}

void executeBuyStop(double entry, double sl=NULL, double tp=NULL){
   Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   if(entry-Ask<ATR[1]*ret) return;
   PositionSize();
   
   if(sl==NULL && SlATR>0) sl=entry-SlATR*ATR[1];
   if(tp==NULL && TpATR>0) tp=entry+TpATR*ATR[1];
   trade.BuyStop(Lot, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, Expiration, text);
}

void executeSellStop(double entry, double sl=NULL, double tp=NULL){
   Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry) return;
   if(Bid-entry<ATR[1]*ret) return;
   PositionSize();
   
   if(sl==NULL && SlATR>0) sl=entry+SlATR*ATR[1];
   if(tp==NULL && TpATR>0) tp=entry-TpATR*ATR[1];
   trade.SellStop(Lot, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, Expiration, text);
}

void range(int bars){
   CopyHigh(_Symbol, Timeframe, 1, bars, High);
   CopyLow(_Symbol, Timeframe, 1, bars, Low);
   Highest = NormalizeDouble(High[ArrayMaximum(High, 0, WHOLE_ARRAY)], _Digits);
   Lowest = NormalizeDouble(Low[ArrayMinimum(Low, 0, WHOLE_ARRAY)], _Digits);
   
   //if(Highest!=oldHigh){
      //closeOrder(ORDER_TYPE_BUY_STOP);
  // }
   //if(Lowest!=oldLow){
      //closeOrder(ORDER_TYPE_SELL_STOP);
   //}
   
   ObjectMove(0, "Max", 0, 0, Highest);
   ObjectMove(0, "Min", 0, 0, Lowest);
   
   oldHigh = Highest;
   oldLow = Lowest;
}

bool inTP(ENUM_POSITION_TYPE type)
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
         double TpPoints = TpATR*ATR[1]/_Point;
         if(PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol && PositionGetInteger(POSITION_TYPE)==type && profitMargin>TpPoints*_Point)
         {
            x =true;
         }
      }
   }
   return x;
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
         if(PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol && PositionGetInteger(POSITION_TYPE)==type && profitMargin>1*_Point)
         {
            x =true;
         }
      }
   }
   return x;
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
   if(n<0) return;
   //Close Positon
   n+=1;
   if(buyDuration>=n){
      closePosition(POSITION_TYPE_BUY);
   }
   if(sellDuration>=n){
      closePosition(POSITION_TYPE_SELL);
   }
}

void snailExit(int n){
   if(TpATR*ATR[1]/_Point<0) return;
   
   if(buyDuration>n  && inTP(POSITION_TYPE_BUY)){
      closePosition(POSITION_TYPE_BUY);
   }
   if(sellDuration>n && inTP(POSITION_TYPE_SELL)){
      closePosition(POSITION_TYPE_SELL);
   }
   breakEven();
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
               Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
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
               Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
               if(Ask<=PositionGetDouble(POSITION_PRICE_OPEN)-TslTriggerPoints*_Point)
               {
                  double Sl = NormalizeDouble(Ask+TslPoints*_Point, _Digits);
                  if(Sl<PositionGetDouble(POSITION_SL) || PositionGetDouble(POSITION_SL)==NULL)
                  {
                     trade.PositionModify(ticket, Sl, PositionGetDouble(POSITION_TP));
                  }
               }               
            }
         }
      }
   }
}


void breakEven(double points=NULL){
   points = BKAtr*ATR[1]/_Point;
   if(points<0) return;
   
   double profitMargin;
   for(int i =0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if (PositionSelectByTicket(ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               profitMargin = PositionGetDouble(POSITION_PRICE_CURRENT)-PositionGetDouble(POSITION_PRICE_OPEN);
            }
            else{
                profitMargin = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
            }
            
            if(profitMargin>points*_Point)
            trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_TP));
         }
      }
   }
}

void preExit(int n){
   if(n<0) return;
   //Close Positon
   n+=1;
   if(buyDuration>=n && !inProfit(POSITION_TYPE_BUY)){
      closePosition(POSITION_TYPE_BUY);
   }
   if(sellDuration>=n && !inProfit(POSITION_TYPE_SELL)){
      closePosition(POSITION_TYPE_SELL);
   }
}

void positionModify(ENUM_POSITION_TYPE type){
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
               //if(type == POSITION_TYPE_BUY)
               //trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN)+tsl*_Point, NULL);
               //if(type == POSITION_TYPE_SELL)
               //trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN)-tsl*_Point, NULL);
            }
         }
      }
   }
}