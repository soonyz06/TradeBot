#include <Trade\Trade.mqh>
CTrade trade;

input ulong Magic = 1200;
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
ENUM_TIMEFRAMES Freq = PERIOD_M5; //Frequency
int A = 8; //Start Time
int Z = 20; //End Time
input double FixedLot = 0;
input double risk = 0.01; //Risk
input int bars = 20; //Lookback
//24, 56, 71
int Distance;
double Lot;
input int TpPoints = 2000;
input int SlPoints = 200;
input int d = 250; //Distance

int TslTriggerPoints = 10;
int TslPoints = 30; 
int R = 1; //Readjust
int S = 5; //Spread Adjustments
int MaxSpread = 5; //
int Spread;
int flag = 0;
double ph1 = 0;
double ph2 = 0;

//40+10 ; 40/100+200
string Trade_Start = string(A)+":00:00"; //Start Time
string Trade_Stop = string(Z)+":00:00"; //End Time
double bar;
double newbar;
double Max;
double Min;
int buyPosition;
int sellPosition;
int buyOrder;
int sellOrder;
string today;
string yesterday;
datetime Start;
datetime Stop;
datetime now;
string text;
double Max2;
double Min2;
double high;
double low;

void OnInit()
{
   ObjectsDeleteAll(0, 0, -1);
   trade.SetExpertMagicNumber(Magic);
   ObjectCreate(0, "High", OBJ_HLINE, 0, _Period, 0);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, _Period, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   bar = 0;
   yesterday = "0";
   text = "S"+string(Magic);
   Distance = 0;
   Max2  = 69;
   Min2 = 69;
   Comment("ID: ", Magic);
   flag = 0;
}

void OnTick()
{
   
   
   //+------------------------------------------------------------------+
   
   //Trail
   //processPosition();
   
   //+------------------------------------------------------------------+
   
   //Time
   now = TimeCurrent();
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {
      yesterday = today;
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
      
   }

   //+------------------------------------------------------------------+
   
   //At each new bar
   newbar = iBars(_Symbol, Timeframe);
   if(bar!=newbar)
   {       
      range();
      snailExit();  
      
      //Readjust Order
      if(R == 1){
         checkOrders();
         if(Max!=Max2)
         closeOrder(ORDER_TYPE_BUY_STOP);
         if(Min!=Min2)
         closeOrder(ORDER_TYPE_SELL_STOP);
      }
      
      //File Order
      checkPositions();
      if(Max>0 && buyPosition == 0)
      {
         executeBuy(Max+3*_Point);  
         ph1 = Max;
         flag = 0;
         Max2 = Max;
      }
      
      if(Min>0 && sellPosition == 0 )
      {
         executeSell(Min-3*_Point);
         ph2 = Min;
         flag = 0;
         Min2 = Min;
      }   
         
      Distance = d;
      bar=newbar;
   }
      
      //checkSpread();
      //Comment("Flag: ", flag);
      //Comment("Spread: ",Spread);
     
   
   
   //Close Order
   if(TimeCurrent()>Stop){
      closeAllPositions();
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
         Lot = balance*risk/slpoints;
      }
      else if (Curr2=="JPY")
      {
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = balance*risk/slpoints*Ask2/100;
      }
      else 
      {
         //USDCHF etc
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = balance*risk/slpoints*Ask2;
         //NZDUSD etc
         if(Lot==0)
         {
            double Bid2 = NormalizeDouble(SymbolInfoDouble(Curr2+"USD", SYMBOL_BID), _Digits);
            balance = AccountInfoDouble(ACCOUNT_BALANCE);
            Lot = balance*risk/slpoints/Bid2;
         }
      }
      if (Lot<0.01)
      {
         Lot = 0.01;
      }
      else if(MathIsValidNumber(Lot) == false)
      {
         balance = AccountInfoDouble(ACCOUNT_BALANCE);
         Lot = NormalizeDouble(balance*risk/slpoints, 1);
      }
      Lot = NormalizeDouble(Lot, 2);
   }
   else
   {
      Lot = FixedLot;
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

void executeBuy(double entry){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   //Distance = int(((Max-Min)/2)/_Point);
   if(Ask+Distance*_Point>entry) return;
   double Sl = NormalizeDouble(entry-SlPoints*_Point, _Digits);
   //double Tp = NormalizeDouble(entry+TpPoints*_Point, _Digits);
   positionSize(SlPoints);
   trade.BuyStop(Lot, entry, _Symbol, Sl, NULL, ORDER_TIME_SPECIFIED, Stop, text);  
}

void executeSell(double entry){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   //Distance = int(((Max-Min)/2)/_Point);
   if(Bid-Distance*_Point<entry) return;
   double Sl = NormalizeDouble(entry+SlPoints*_Point, _Digits);
   //double Tp = NormalizeDouble(entry-TpPoints*_Point, _Digits);
   positionSize(SlPoints);
   trade.SellStop(Lot, entry, _Symbol, Sl, NULL, ORDER_TIME_SPECIFIED, Stop, text);
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

void closeAllPositions()
{
   for (int i=PositionsTotal()-1; i>=0; i--)
      {  
         ulong ticket = PositionGetTicket(i);
         if (PositionSelectByTicket(ticket))
         {
            string symbol = PositionGetSymbol(i);
            if (PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol)
            {
               trade.PositionClose(ticket);
            }
         }
      }
}

void checkOrders()
{
   buyOrder = 0;
   sellOrder = 0;
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
               buyOrder+=1;
            }
            else if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_STOP)
            {
               sellOrder+=1;
            }
         }
      }
   }
}

void Breakeven()
{
   for(int i =0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      if (PositionSelectByTicket(ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol)
         {
            trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_PRICE_OPEN));
         }
      }
   }
}

void SpreadModify(int Limit)
{
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
               if(Limit==1){
                  trade.OrderModify(ticket, ph1+S*_Point, PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP), ORDER_TIME_SPECIFIED, Stop);
               }
               if(Limit==0){// && ph1!=OrderGetDouble(ORDER_PRICE_OPEN)){
                  trade.OrderModify(ticket, ph1, PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP), ORDER_TIME_SPECIFIED, Stop);               
               }
            }
            else if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_STOP)
            {
               if(Limit==1){
                  trade.OrderModify(ticket, ph2-S*_Point, PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP), ORDER_TIME_SPECIFIED, Stop);
               }
               if(Limit ==0){// && ph2!=OrderGetDouble(ORDER_PRICE_OPEN)){
                  trade.OrderModify(ticket, ph2, PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP), ORDER_TIME_SPECIFIED, Stop);
               }
            }
         }
      }
   }
}

void checkSpread(){
   if (MaxSpread == 0) return;
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   Spread = int((Ask-Bid)/_Point);
   
   if(Spread>=MaxSpread && flag == 0){
      SpreadModify(1);
      flag = 1;
   }
   if(Spread<=(4.5) && flag == 1){
      SpreadModify(0);
      flag = 0;
   }
   //R
}

void snailExit(){
   if(TpPoints<0) return;
   
   if(inProfit(POSITION_TYPE_BUY, 1)){
      closePosition(POSITION_TYPE_BUY);
   }
   if(inProfit(POSITION_TYPE_SELL, 1)){
      closePosition(POSITION_TYPE_SELL);
   }
}

bool inProfit(ENUM_POSITION_TYPE type, int mode)
{
   int trigger;
   bool x = false;
   double profitMargin;
   
   
   if(mode==0) //inProfit above 0 points
   trigger = 0;
   else //inProfit above x points
   trigger  = TpPoints;
   
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
         if(PositionGetInteger(POSITION_MAGIC)==Magic && symbol == _Symbol && PositionGetInteger(POSITION_TYPE)==type && profitMargin>trigger*_Point)
         {
            x =true;
         }
      }
   }
   return x;
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

void range(){
   //High and Low of last 20 bars
   double High[];
   CopyHigh(_Symbol, Timeframe, 0, bars, High);
   double Low[];
   CopyLow(_Symbol, Timeframe, 0, bars, Low);
   Max = High[ArrayMaximum(High, 0, WHOLE_ARRAY)];
   Min = Low[ArrayMinimum(Low, 0, WHOLE_ARRAY)];
   ObjectMove(0, "High", 0, _Period, Max);
   ObjectMove(0, "Low", 0, _Period, Min);
}