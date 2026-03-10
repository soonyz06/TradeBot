#include<Trade\Trade.mqh>
CTrade trade;

input group "===   Inputs   ===";
input ulong Magic = 013;
input ENUM_TIMEFRAMES Timeframe = PERIOD_D1;
input double FixedLot = 0.01;
input double VariableLot = 0;
double Lot;
int Mode = 0;

input group "===   Settings   ===";
int TpPoints1 = -1; //Tp 
int TpPoints2 = TpPoints1; 
input int SlPoints = 2000;
input int TimeExit1 = 50; //Time Exit
int TimeExit2= TimeExit1;
int TriggerPoints = 0;
input int len = 30; //Band Length
int std = 2; //Standard Deviation
input bool CF = true; //Confirmation
int Confirmation = -1;

input group "===   Time   ===";
input int A = 1; //Start Time
int B = 23; //Stop Time
input int Z = 1; //Exit Time
int E = 18; //Expiration Time

//Variables
string today;
string yesterday;
datetime Start;
datetime Stop;
datetime Exit;
datetime Expiration;
string Trade_Start = string(A)+":15:00"; //Start Time
string Trade_Stop = string(B)+":15:00"; //Stop Time ///?
string Trade_Exit = string(Z)+":05:00"; //Exit Time
string Trade_Expiration = string(E)+":00:00"; //Expiration Time
int bar1;
int bar2;
int newbar;
string text;
int buyPosition;
int sellPosition;
int buyDuration =-1;
int sellDuration =-1;

MqlRates Price[];
double High[];
double Low[];
double Highest = 0;
double Lowest = DBL_MAX;
double oldHigh;
double oldLow;
double Upper[];
double Lower[];
double Middle[];
int BBHandler;

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
   ArraySetAsSeries(Upper, true);
   ArraySetAsSeries(Lower, true);
   ArraySetAsSeries(Middle, true);
   ObjectCreate(0, "High", OBJ_HLINE, 0, 0, 0);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   BBHandler = iBands(_Symbol, Timeframe, len, 0, std, PRICE_CLOSE);
   if(BBHandler==INVALID_HANDLE) Alert("Invalid Handle");
   if(CF) Confirmation = 10;
    
   Comment("ID: ", Magic);
   CheckPositions();
}

void OnTick(){
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
      Exit = StringToTime(today+" "+Trade_Exit);
      Expiration = StringToTime(today+" "+Trade_Expiration);
         
      CopyRates(_Symbol, Timeframe, 0, 3, Price);
      CopyBuffer(BBHandler, 0, 0, 3, Middle);
      CopyBuffer(BBHandler, 1, 0, 3, Upper);
      CopyBuffer(BBHandler, 2, 0, 3, Lower);
      Range(Confirmation);
      yesterday=today;
   }


   newbar= iBars(_Symbol, Timeframe);
   //Entry
   if(bar1!=newbar){
      if(TimeCurrent()>Start){
         CheckPositions();
         
         if(Price[2].close>Upper[2] && Price[1].close<Upper[1] && Price[1].close>Middle[1] && Price[2].close>Highest){
            if(sellPosition==0 && buyPosition==0){
               ExecuteSell();
               SendNotification("Sell"+string(_Symbol));
            }
         }
         if(Price[2].close<Lower[2] && Price[1].close>Lower[1] && Price[1].close<Middle[1] && Price[2].close<Lowest){
            if(buyPosition==0 && sellPosition==0){
               ExecuteBuy();    
               SendNotification("Buy"+string(_Symbol));
            }
         }
         bar1=newbar;
      }
   }
   
   //Exit
   if(bar2!=newbar){
      if(TimeCurrent()>=Exit){
         if(Price[1].close>Upper[1] || Price[1].open>Upper[1]){
            ClosePosition(POSITION_TYPE_BUY);
         }
         if(Price[1].close<Lower[1] || Price[1].open<Lower[1]){
            ClosePosition(POSITION_TYPE_SELL);
         }
         CheckPositions();
         TimeExit();
         bar2=newbar;
      
      }
   }
}



//---------------------------------------------------------------------------------------------------------



void PositionSize(){
   if(FixedLot>0){
      Lot=FixedLot;
   }
   else if(VariableLot<0){
      Lot = 0.01;
   }
   else{
      Lot = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE)/400*VariableLot, 2);
   }
   
   if(Lot<0.01) Lot=0.01;
   if(Lot>10) Lot=10;
}

void ExecuteBuy(double slpoints=NULL, double tppoints=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(tppoints==0 && Mode==0 && TpPoints1>0) tppoints = Ask+TpPoints1*_Point;
   if(slpoints==0 && SlPoints>0) slpoints = Ask-SlPoints*_Point;
   
   PositionSize();
   trade.Buy(Lot, _Symbol, Ask, slpoints, tppoints, text);
}

void ExecuteSell(double slpoints=NULL, double tppoints=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(tppoints==0 && Mode==0 && TpPoints2>0) tppoints = Bid-TpPoints2*_Point;
   if(slpoints==0 && SlPoints>0) slpoints = Bid+SlPoints*_Point;
   
   PositionSize();
   trade.Sell(Lot, _Symbol, Bid, slpoints, tppoints, text);
}

void ExecuteBuyStop(double entry, double sl=NULL, double tp=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlPoints>0) _sl=entry-SlPoints*_Point;
   if(tp==NULL && TpPoints1>0 && Mode==0) _tp=entry+TpPoints1*_Point;
   PositionSize();
   trade.BuyStop(Lot, entry, _Symbol, _sl, _tp, NULL, NULL, text);
   
}

void ExecuteSellStop(double entry, double sl=NULL, double tp=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlPoints>0) _sl=entry+SlPoints*_Point;
   if(tp==NULL && TpPoints2>0 && Mode==0) _tp=entry-TpPoints2*_Point;
   PositionSize();
   trade.SellStop(Lot, entry, _Symbol, _sl, _tp, NULL, NULL, text);
}

void CheckPositions(){  

   bool WasInPosition;
   if(buyDuration>=0 || sellDuration>=0) WasInPosition=true;
   else WasInPosition=false;
   
   buyPosition=0;
   sellPosition=0;
   buyDuration = -1;
   sellDuration = -1;
   
   ulong _ticket;
   
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
   
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(_ticket)){
         if(PositionGetInteger(POSITION_MAGIC) == Magic && PositionGetString(POSITION_SYMBOL) == _Symbol){
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               buyPosition+=1;
               buyDuration = iBarShift(_Symbol, Timeframe, PositionGetInteger(POSITION_TIME), false);
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               sellPosition+=1;
               sellDuration = iBarShift(_Symbol, Timeframe, PositionGetInteger(POSITION_TIME), false);
            }
         }
      }
   }
   
   Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration);
}

void TimeExit(){
   if(buyDuration>=TimeExit1 && TimeExit1>0) ClosePosition(POSITION_TYPE_BUY);
   if(sellDuration>=TimeExit2 && TimeExit2>0) ClosePosition(POSITION_TYPE_SELL);
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
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){
               _profitMargin = PositionGetDouble(POSITION_PRICE_CURRENT)-PositionGetDouble(POSITION_PRICE_OPEN);
               TriggerPoints=TpPoints1;
            }
            else{
               _profitMargin = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
               TriggerPoints=TpPoints2;
            }
            
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
   if(bars<=0) return;
   
   CopyHigh(_Symbol, Timeframe, 3, bars, High);
   CopyLow(_Symbol, Timeframe, 3, bars, Low);
   Highest = NormalizeDouble(High[ArrayMaximum(High, 0, WHOLE_ARRAY)], _Digits);
   Lowest = NormalizeDouble(Low[ArrayMinimum(Low, 0, WHOLE_ARRAY)], _Digits);
   
   if(Highest!=oldHigh){
      ObjectMove(0, "High", 0, 0, Highest);
      oldHigh = Highest;
   }
   if(Lowest!=oldLow){
      ObjectMove(0, "Low", 0, 0, Lowest);
      oldLow = Lowest;
   }
}