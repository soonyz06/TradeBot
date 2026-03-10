#include <Trade\Trade.mqh>
CTrade trade;

input ulong Magic = 1100;
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input ENUM_TIMEFRAMES Freq = PERIOD_M5; //Frequency
input double FixedLot = 0;
input double risk = 0.01; //Risk
input int BarsN = 10;
int x = 1; // Time Filter
input double OrderDistancePoints = 200;
double Lot;
double TpPoints = 2000 ;
double SlPoints = 200 ;
input double TslTriggerPoints = 40 ;
input double TslPoints = 10 ; 
int Order;
int bar;
int newbar;
string Trade_Start = "1:00:00"; //Start Time
string Trade_Stop = "20:00:00"; //End Time
string today;
string yesterday;
datetime Start;
datetime Stop;
int buyPosition;
int sellPosition;
string symbols;
datetime now;
string text;

void OnInit()
{
   trade.SetExpertMagicNumber(Magic);
   ObjectCreate(0, "High", OBJ_HLINE, 0, _Period, 0);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, _Period, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   bar = 0;
   yesterday = "0";
   text = "S"+string(Magic);
   Comment("ID: ", Magic);
}

void OnTick()
{     
   now = TimeCurrent();
   //Time
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {
      yesterday = today;
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
   }
   
   newbar = iBars(_Symbol, Freq);
   if(bar!=newbar)
   {
      bar = newbar;
      
      //Readjust Orders
      double high = FindHigh();
      double low = FindLow();
      
      //File Orders
      checkPositions();
      if(high>0)
      {
         ObjectMove(0, "High", 0, _Period, high);
         if(((now>Start && now<Stop) || x==0) && buyPosition<=0){
            ExecuteBuy(high);    
         }
      }
     
      if(low>0)
      {
         ObjectMove(0, "Low", 0, _Period, low);
         if(((now>Start && now<Stop) || x==0) && sellPosition<=0){
            ExecuteSell(low);   
         }
      }      
   }
   
   //Trail
   processPosition();
}

//+------------------------------------------------------------------+

double FindHigh()
{
   double highestHigh = 0;
   for(int i =0; i<200; i++)
   {
      double high = iHigh(_Symbol, Timeframe, i);
      if(iHighest(_Symbol, Timeframe, MODE_HIGH, BarsN*2+1, i-BarsN)==i)
      {
         if(high>highestHigh)
         {
            return high;
         }
      }
      highestHigh = MathMax(high, highestHigh);
   }
   return -1;
}

double FindLow()
{
   double lowestLow = DBL_MAX;
   for(int i =0; i<200; i++)
   {
      double low = iLow(_Symbol, Timeframe, i);
      if(iLowest(_Symbol, Timeframe, MODE_LOW, BarsN*2+1, i-BarsN)==i)
      {
         if(low<lowestLow)
         {
            return low;
         }
      }
      lowestLow = MathMin(low, lowestLow);
   }
   return -1;
}

void ExecuteBuy(double entry)
{
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry-OrderDistancePoints*_Point) return;
   datetime expiration = iTime(_Symbol, Timeframe, 0) + 50*PeriodSeconds(Timeframe);
   double Sl = NormalizeDouble(entry-SlPoints*_Point, _Digits);
   double Tp = NormalizeDouble(entry+TpPoints*_Point, _Digits);
   PositionSize(SlPoints);
   trade.BuyStop(Lot, NormalizeDouble(entry, _Digits), _Symbol, Sl, Tp, ORDER_TIME_SPECIFIED, Stop, text); 
}

void ExecuteSell(double entry)
{
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry+OrderDistancePoints*_Point) return;
   datetime expiration = iTime(_Symbol, Timeframe, 0) + 50*PeriodSeconds(Timeframe);
   double Sl = NormalizeDouble(entry+SlPoints*_Point, _Digits);
   double Tp = NormalizeDouble(entry-TpPoints*_Point, _Digits);
   PositionSize(SlPoints);
   trade.SellStop(Lot, NormalizeDouble(entry, _Digits), _Symbol, Sl, Tp, ORDER_TIME_SPECIFIED, Stop, text);
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
               if(Bid>PositionGetDouble(POSITION_PRICE_OPEN)+TslTriggerPoints*_Point)
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
               if(Ask<PositionGetDouble(POSITION_PRICE_OPEN)-TslTriggerPoints*_Point)
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

void PositionSize(double slpoints)
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


