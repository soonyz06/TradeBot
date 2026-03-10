#include<Trade\Trade.mqh>
CTrade trade;

//Inputs
input ulong Magic = 028;
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input double FixedLot = 0.01;
input int TpPoints = 3500; 
input int SlPoints = 750;
int TriggerPoints;
input int TimeExit= 210;
input int Buffer = 0;
input int ret = 69; //Retracement
//100 100, 0 0
input string Time; //
input int A = 1; //Start Time
int B = 20; //Stop Time
int Z = 1; //End Time
int E = 18;

//Tp 3500 or 4000 ~ 4500
//[(Tp=3000 or 4000) and Sl=1000] //Not Stable
//Result [Tp=3500 and Sl=750] ~ Sl=2000 

//Variables
string today;
string yesterday;
datetime Start;
datetime Stop;
datetime End;
datetime Expiration;
string Trade_Start = string(A)+":15:00"; //Start Time
//string Trade_Stop = string(B)+":00:00"; //Start Time
string Trade_End = string(Z)+":05:00"; //End Time
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
double Upper[];
double Lower[];
int BBHandler;
double High[];
double Low[];
double Max;
double Min;
double oldMax;
double oldMin;



//---------------------------------------------------------------------------------------------------------



void OnInit(){
   trade.SetExpertMagicNumber(Magic);
   text = string(Magic);
   bar1=0;
   bar2=0;
   yesterday="";
   oldMax=0;
   oldMin=0;
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(Upper, true);
   ArraySetAsSeries(Lower, true);
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   //BBHandler = iBands(_Symbol, Timeframe, 100, 0, 3, PRICE_CLOSE);
   ObjectCreate(0, "High", OBJ_HLINE, 0, 0, 0);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   
   Comment("ID: ", Magic);
}



//MADE REDUNDANT BY 017TURTLEMINI 
void OnTick(){
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      //Stop = StringToTime(today+" "+Trade_Stop);
      End = StringToTime(today+" "+Trade_End);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      
      yesterday=today;
   }


   newbar= iBars(_Symbol, Timeframe);
   if(bar1!=newbar){
      if(TimeCurrent()>Start && today != "2018.02.27"){
         CopyRates(_Symbol, Timeframe, 0, 3, Price);
         //CopyBuffer(BBHandler, 1, 0, 3, Upper);
         //CopyBuffer(BBHandler, 2, 0, 3, Lower);
         
         CopyHigh(_Symbol, Timeframe, 0, 71, High);
         CopyLow(_Symbol, Timeframe, 0, 71, Low);
         Max = High[ArrayMaximum(High, 1)];
         Min = Low[ArrayMinimum(Low, 1)];
         ObjectMove(0, "High", 0, _Period, Max*_Point);
         ObjectMove(0, "Low", 0, _Period, Min*_Point);
         
         CheckPositions(buyPosition, sellPosition, true);
         //Print(buyPosition, sellPosition);
         Print(today);
         OrderEntry(); //spread, false entry
         
         bar1=newbar;
      }
   }
   
   if(bar2!=newbar){
      if(TimeCurrent()>End || Timeframe!=PERIOD_D1){
         TimeUpdate(buyDuration, sellDuration);
         TimeExit(TimeExit, buyDuration, sellDuration);
         bar2=newbar;
         
         if(today == "2018.02.28"){
            ClosePosition(POSITION_TYPE_BUY);
            ClosePosition(POSITION_TYPE_SELL);
         }
      }
   }
}



//---------------------------------------------------------------------------------------------------------



void ExecuteBuy(double slpoints=NULL, double tppoints=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(tppoints!=0) tppoints = Ask+tppoints*_Point;
   if(slpoints!=0) slpoints = Ask-slpoints*_Point;
   
   trade.Buy(FixedLot, _Symbol, Ask, slpoints, tppoints, text);
}

void ExecuteSell(double slpoints=NULL, double tppoints=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(tppoints!=0) tppoints = Bid-tppoints*_Point;
   if(slpoints!=0) slpoints = Bid+slpoints*_Point;
   
   trade.Sell(FixedLot, _Symbol, Bid, slpoints, tppoints, text);
}

void ExecuteBuyStop(double entry, double sl=NULL, double tp=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   if(entry-Ask<ret*_Point) return;
   
   trade.BuyStop(FixedLot, entry, _Symbol, sl, tp, NULL, NULL, text);
   
}

void ExecuteSellStop(double entry, double sl=NULL, double tp=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Bid<entry) return;
   if(Bid-entry<ret*_Point) return;
   
   trade.SellStop(FixedLot, entry, _Symbol, sl, tp, NULL, NULL, text);
}

void CheckPositions(int& _buyPosition, int& _sellPosition, bool inclusive = true){  
   _buyPosition=0;
   _sellPosition=0;
   
   ulong _ticket;
   
   if(inclusive == true){
      for(int i=0; i<OrdersTotal(); i++){
         _ticket = OrderGetTicket(i);
         
         if(OrderSelect(_ticket)){
            if(OrderGetInteger(ORDER_MAGIC) == Magic && OrderGetString(ORDER_SYMBOL) == _Symbol){
               if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT){
                  _buyPosition+=1;
               }
               else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP ||OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT){
                  _sellPosition+=1;
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
               _buyPosition+=1;
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               _sellPosition+=1;
            }
         }
      }
   }
}

void TimeUpdate(int& _buyDuration , int& _sellDuration){
   _buyDuration = 0;
   _sellDuration = 0;
   
   ulong _ticket;
   
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(_ticket)){
         if(PositionGetInteger(POSITION_MAGIC) == Magic && PositionGetString(POSITION_SYMBOL) == _Symbol){
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               _buyDuration = iBarShift(_Symbol, Timeframe, PositionGetInteger(POSITION_TIME), false);
            }
            else if(PositionGetInteger(POSITION_TYPE)== POSITION_TYPE_SELL){
               _sellDuration = iBarShift(_Symbol, Timeframe, PositionGetInteger(POSITION_TIME), false);
               
            }
         }
      }
   }
   
   Comment("ID: ", Magic, "\nBuy Duration: ", _buyDuration, "\nSell Duration: ", _sellDuration);
}

void TimeExit(int n, int _buyDuration, int _sellDuration){
   if(_buyDuration>=n) ClosePosition(POSITION_TYPE_BUY);
   if(_sellDuration>=n) ClosePosition(POSITION_TYPE_SELL);
}

void ClosePosition(ENUM_POSITION_TYPE _type){
   int _total = PositionsTotal();
   int _closed = 0;
   int i;
   ulong _ticket;
   
   for(int j =0; j<_total; j++)
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

void CloseOrder(ENUM_ORDER_TYPE _type)
{  
   int _total = OrdersTotal();
   int _closed = 0;
   int i;
   ulong _ticket;
   
   for(int j =0; j<_total; j++)
   {  
      i = j-_closed;
      _ticket = OrderGetTicket(i);
      
      if (OrderSelect(_ticket))
      { 
         if (OrderGetInteger(ORDER_MAGIC)==Magic && OrderGetString(ORDER_SYMBOL) == _Symbol)
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

void OrderEntry(){
   if(oldMax!=Max){
      CloseOrder(ORDER_TYPE_BUY_STOP);
      if(buyPosition==0){
         ExecuteBuyStop(Max+Buffer*_Point, Max-SlPoints*_Point, Max+TpPoints*_Point);
         ObjectMove(0, "High", 0, _Period, Max);
         oldMax = Max;
      }
   }
   if(oldMin!=Min){
      CloseOrder(ORDER_TYPE_SELL_STOP);
      if(sellPosition==0){
         ExecuteSellStop(Min-Buffer*_Point, Min+SlPoints*_Point, Min-TpPoints*_Point);
         ObjectMove(0, "Low", 0, _Period, Min);
         oldMin = Min;
      }
   }
}

void PositionEntry(){
   if(Price[0].close>Max){
      if(buyPosition==0)
         ExecuteBuy(SlPoints, TpPoints);
   }
   if(Price[0].close<Min){
      if(sellPosition==0)
         ExecuteSell(SlPoints, TpPoints);
   }
}