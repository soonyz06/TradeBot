#include<Trade\Trade.mqh>
CTrade trade;

//Inputs
input ulong Magic = 027;
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input double FixedLot = 0.01;
input int TpPoints = 7000;
input int SlPoints = 2000;
//500 1000 2000
//6k, 2k or 500, 6/10k
int TriggerPoints = -1;
input int TimeExitLong= 200;
input int TimeExitShort= 250;
input string Time; //
input int A = 8; //Start Time
int B = 1; //Stop Time
int Z = 1; //End Time
int E = 18;
//old 10000 2600 200 300 1

//Variables
string today;
string yesterday;
datetime Start;
datetime Stop;
datetime End;
datetime Expiration;
string Trade_Start = string(A)+":15:00"; //Start Time
string Trade_Stop = string(B)+":00:00"; //Stop Time
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



//---------------------------------------------------------------------------------------------------------



void OnInit(){
   trade.SetExpertMagicNumber(Magic);
   text = string(Magic);
   bar1=0;
   bar2=0;
   yesterday="";
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(Upper, true);
   ArraySetAsSeries(Lower, true);
   BBHandler = iBands(_Symbol, Timeframe, 100, 0, 3, PRICE_CLOSE);
   Comment("ID: ", Magic);
}

void OnTick(){
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
      End = StringToTime(today+" "+Trade_End);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      
      yesterday=today;
   }


   newbar= iBars(_Symbol, Timeframe);
   if(bar1!=newbar){
      if(TimeCurrent()>=Start){
         CopyRates(_Symbol, Timeframe, 0, 3, Price);
         CopyBuffer(BBHandler, 1, 0, 3, Upper);
         CopyBuffer(BBHandler, 2, 0, 3, Lower);
         CheckPositions(buyPosition, sellPosition);
         
         if(Price[1].close>Upper[1]){
            if(buyPosition+sellPosition==0)
            ExecuteBuy(SlPoints, TpPoints);
            
         }
         if(Price[1].close<Lower[1]){
            if(buyPosition+sellPosition==0)
            ExecuteSell(SlPoints, TpPoints);
            
         }
         bar1=newbar;
      }
   }
   
   if(bar2!=newbar){
      if(TimeCurrent()>End || Timeframe!=PERIOD_D1){
         TimeUpdate(buyDuration, sellDuration);
         TimeExit(buyDuration, sellDuration);
         bar2=newbar;
         
         //if(InProfit(POSITION_TYPE_BUY, TriggerPoints) || InProfit(POSITION_TYPE_SELL, TriggerPoints)) BreakEven();
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
   
   trade.BuyStop(FixedLot, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, Expiration, text);
   
}

void ExecuteSellStop(double entry, double sl=NULL, double tp=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Bid<entry) return;
   
   trade.SellStop(FixedLot, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, Expiration, text);
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

void TimeExit(int _buyDuration, int _sellDuration){
   if(_buyDuration>=TimeExitLong) ClosePosition(POSITION_TYPE_BUY);
   if(_sellDuration>=TimeExitShort) ClosePosition(POSITION_TYPE_SELL);
}

void ClosePosition(ENUM_POSITION_TYPE _type){
   int _closed = 0;
   int i;
   ulong _ticket;
   
   for(int j =0; j<PositionsTotal(); j++)
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

bool InProfit(ENUM_POSITION_TYPE type, int margin){
   if(margin<1) return false;
   
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
            
            if(type == PositionGetInteger(POSITION_TYPE) && _profitMargin>margin*_Point){
               return true;
            }
         }
      }
   }
   return false;
}

void BreakEven(){
   if(buyDuration<30 && sellDuration<30) return;
   
   ulong _ticket;
   long _magic;
   string _symbol;
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(_ticket))
      {
         _magic = PositionGetInteger(POSITION_MAGIC);
         _symbol = PositionGetString(POSITION_SYMBOL);
         if(_magic == Magic && _symbol == _Symbol)
         {
            if(PositionGetDouble(POSITION_SL)!=PositionGetDouble(POSITION_PRICE_OPEN)){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                  trade.PositionModify(_ticket, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_TP));  
               else 
                  trade.PositionModify(_ticket, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_TP));
               return; 
            }
         }
      }  
   }
}