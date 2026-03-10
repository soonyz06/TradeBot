#include<Trade\Trade.mqh>
CTrade trade;

//Inputs
input ulong Magic = 032;
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input double FixedLot = 0.01;
input int Mode = 0;

input string Settings; //
input int TpPoints = 2000;
input int SlPoints = 1500;
int TriggerPoints = TpPoints;
input int TimeExit1= 10;
input int TimeExit2= 10;

input string Time; //
input int A = 1; //Start Time
input int B = 1; //Stop Time
input int Z = 1; //Exit Time
int E = 18;

//Variables
string today;
string yesterday;
datetime Start;
datetime Stop;
datetime Exit;
datetime Expiration;
string Trade_Start = string(A)+":15:00"; //Start Time
string Trade_Stop = string(A)+":15:00"; //Stop Time
string Trade_Exit = string(Z)+":05:00"; //Exit Time
string Trade_Expiration = string(E)+":00:00"; //Expiration Time
int bar1;
int bar2;
int newbar;
string text;
int buyPosition;
int sellPosition;
int buyDuration;
int sellDuration;

MqlRates Price[];
double High[];
double Low[];
double Highest;
double Lowest;
double oldHigh;
double oldLow;

//---------------------------------------------------------------------------------------------------------



void OnInit(){
   trade.SetExpertMagicNumber(Magic);
   text = string(Magic);
   bar1=0;
   bar2=0;
   yesterday="";
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   
   Comment("ID: ", Magic);
}

void OnTick(){
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
      Exit = StringToTime(today+" "+Trade_Exit);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      
      yesterday=today;
   }


   newbar= iBars(_Symbol, Timeframe);
   if(bar1!=newbar){
      CopyRates(_Symbol, Timeframe, 0, 3, Price);
      Expiration();
      CheckPositions();
      
      //Entry
      if(TimeCurrent()>=Start){
         if(Price[1].close<Price[2].low && Price[2].close<Price[2].open){
            if(buyPosition+sellPosition==0)
               ExecuteBuyStop(Price[1].high);
         }
            
         if(Price[1].close>Price[2].high && Price[2].close>Price[2].open){
            if(buyPosition+sellPosition==0)
               ExecuteSellStop(Price[1].low);
         }
      }
      bar1=newbar;
   }
   
   if(bar2!=newbar){
      if(TimeCurrent()>=Exit || Timeframe!=PERIOD_D1){
      
         bar2=newbar;
      
      }
   }
}



//---------------------------------------------------------------------------------------------------------



void ExecuteBuy(double slpoints=NULL, double tppoints=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(tppoints!=0 && Mode==0) tppoints = Ask+tppoints*_Point;
   if(slpoints!=0) slpoints = Ask-slpoints*_Point;
   
   trade.Buy(FixedLot, _Symbol, Ask, slpoints, tppoints, text);
}

void ExecuteSell(double slpoints=NULL, double tppoints=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(tppoints!=0 && Mode==0) tppoints = Bid-tppoints*_Point;
   if(slpoints!=0) slpoints = Bid+slpoints*_Point;
   
   trade.Sell(FixedLot, _Symbol, Bid, slpoints, tppoints, text);
}

void ExecuteBuyStop(double entry, double sl=NULL, double tp=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlPoints>0) _sl=entry-SlPoints*_Point;
   if(tp==NULL && TpPoints>0 && Mode==0) _tp=entry+TpPoints*_Point;
   trade.BuyStop(FixedLot, entry, _Symbol, _sl, _tp, NULL, NULL, text);
   
}

void ExecuteSellStop(double entry, double sl=NULL, double tp=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Bid<entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlPoints>0) _sl=entry+SlPoints*_Point;
   if(tp==NULL && TpPoints>0 && Mode==0) _tp=entry-TpPoints*_Point;
   trade.SellStop(FixedLot, entry, _Symbol, _sl, _tp, NULL, NULL, text);
}

void CheckPositions(bool inclusive = true){  
   buyPosition=0;
   sellPosition=0;
   
   ulong _ticket;
   
   if(inclusive == true){
      for(int i=0; i<OrdersTotal(); i++){
         _ticket = OrderGetTicket(i);
         
         if(OrderSelect(_ticket)){
            if(OrderGetInteger(ORDER_MAGIC) == Magic && OrderGetString(ORDER_SYMBOL) == _Symbol){
               if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT){
                  buyPosition+=1;
               }
               else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP ||OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT){
                  sellPosition+=1;
               }
            }
         }
      }
   }
   
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(_ticket)){
         if(PositionGetInteger(POSITION_MAGIC) == Magic && PositionGetString(POSITION_SYMBOL) == _Symbol){
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               buyPosition+=1;
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               sellPosition+=1;
            }
         }
      }
   }
}

void TimeUpdate(){
   buyDuration = 0;
   sellDuration = 0;
   
   ulong _ticket;
   
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(_ticket)){
         if(PositionGetInteger(POSITION_MAGIC) == Magic && PositionGetString(POSITION_SYMBOL) == _Symbol){
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               buyDuration = iBarShift(_Symbol, Timeframe, PositionGetInteger(POSITION_TIME), false);
            }
            else if(PositionGetInteger(POSITION_TYPE)== POSITION_TYPE_SELL){
               sellDuration = iBarShift(_Symbol, Timeframe, PositionGetInteger(POSITION_TIME), false);
               
            }
         }
      }
   }
   
   Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration);
}

void TimeExit(){
   if(TimeExit1<0 && buyPosition>0) return; 
   if(TimeExit2<0 && sellPosition>0) return;
   
   if(buyDuration>=TimeExit1) ClosePosition(POSITION_TYPE_BUY);
   if(sellDuration>=TimeExit2) ClosePosition(POSITION_TYPE_SELL);
}

void ClosePosition(ENUM_POSITION_TYPE _type){
   int _closed = 0;
   int i;
   ulong _ticket;
   int total = PositionsTotal();
   for(int j =0; j<total; j++)
   {
      i = j-_closed;      
      _ticket = PositionGetTicket(i);
      
      if (PositionSelectByTicket(_ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && PositionGetString(POSITION_SYMBOL)== _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE) == _type)
            {
               trade.PositionClose(_ticket);
               _closed +=1;
            }
         }
      }
   }
}

void CloseOrder(ENUM_ORDER_TYPE _type){
   int _closed = 0;
   int i;
   ulong _ticket;
   int total = OrdersTotal();
   for(int j =0; j<total; j++)
   {
      i = j-_closed;      
      _ticket = OrderGetTicket(i);
      
      if (OrderSelect(_ticket))
      {
         if (OrderGetInteger(ORDER_MAGIC)==Magic && OrderGetString(ORDER_SYMBOL)== _Symbol)
         {
            if(OrderGetInteger(ORDER_TYPE) == _type)
            {
               trade.OrderDelete(_ticket);
               _closed +=1;
            }
         }
      }
   }
}

bool InProfit(ENUM_POSITION_TYPE type){
   ulong _ticket;
   double _profitMargin;
   
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if (PositionSelectByTicket(_ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
               _profitMargin = PositionGetDouble(POSITION_PRICE_CURRENT)-PositionGetDouble(POSITION_PRICE_OPEN);
            else
               _profitMargin = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
            
            if(type == PositionGetInteger(POSITION_TYPE) && _profitMargin>TriggerPoints*_Point){
               return true;
            }
         }
      }
   }
   return false;
}

void ProcessPosition(){ ///? or fixed
   if(TriggerPoints<0 || Mode==0) return;
   
   if(InProfit(POSITION_TYPE_BUY)){
      ClosePosition(POSITION_TYPE_BUY);
   }
   if(InProfit(POSITION_TYPE_SELL)){
      ClosePosition(POSITION_TYPE_SELL);
   }
}

void Range(int bars){
   CopyHigh(_Symbol, Timeframe, 1, bars, High);
   CopyLow(_Symbol, Timeframe, 1, bars, Low);
   Highest = NormalizeDouble(High[ArrayMaximum(High, 0, WHOLE_ARRAY)], _Digits);
   Lowest = NormalizeDouble(Low[ArrayMinimum(Low, 0, WHOLE_ARRAY)], _Digits);
   
   if(Highest!=oldHigh){
      ObjectMove(0, "Max", 0, 0, Highest);
      oldHigh = Highest;
   }
   if(Lowest!=oldLow){
      ObjectMove(0, "Min", 0, 0, Lowest);
      oldLow = Lowest;
   }
}

void Expiration(){
   if(buyPosition+sellPosition==0) return;
   
   if(buyPosition>0 && Price[1].low<Price[2].low)
   CloseOrder(ORDER_TYPE_BUY_STOP);
   if(sellPosition>0 && Price[1].high>Price[2].high)
   CloseOrder(ORDER_TYPE_SELL_STOP);
}