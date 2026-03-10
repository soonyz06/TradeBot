#include<Trade\Trade.mqh>
CTrade trade;

input group "===   Inputs   ===";
input ulong Magic = 115;
input ENUM_TIMEFRAMES Timeframe = PERIOD_M5;
input double FixedRisk = 0.01;
input double VariableRisk = 0;
input double MinLot = 1;
double Lot;
int Mode = 0;
double initial_balance;

input group "===   Settings   ===";
int TpPer = -1; //TP Percentage
input double SlPer= 1; //SL Percentage
double retracement = .5;
input int TimeExit1 = -1; //Time Exit
int TimeExit2= TimeExit1;
double TriggerATR = 0;

input group "===   Time   ===";
input int RS = 3; //Range Start
input int A = 9; //Trade Start
input int Z = 16; //Exit Time
int E = Z; //Expiration Time
//16:30-23:00

//Variables
string today;
string yesterday;
string yesterday2;
string yesterday3;
datetime R_Start;
datetime R_End;
datetime T_Start;
datetime Exit;
datetime Expiration;
string Range_Start = string(RS)+":05:00";
string Range_End = string (A)+":00:00"; 
string Trade_Start = string(A)+":05:00"; 
string Trade_Exit = string(Z)+":05:00"; 
string Trade_Expiration = string(E)+":00:00"; 
int bar1;
int bar2;
int newbar;
string text;
int buyPosition;
int sellPosition;
int buyOrder;
int sellOrder;
int buyDuration =-1;
int sellDuration =-1;

MqlRates Price[];
double High[];
double Low[];
double Highest = 0;
double Lowest = DBL_MAX;
double oldHigh;
double oldLow;
double ATR[];
int ATRHandler;
double MA[];
int MAHandler;
double open;
bool flag1;
bool flag2;



//---------------------------------------------------------------------------------------------------------



void OnInit(){
   trade.SetExpertMagicNumber(Magic);
   text = string(Magic);
   bar1=0;
   bar2=0;
   yesterday="";
   yesterday2="";
   yesterday3="";
   initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   ArraySetAsSeries(ATR, true);
   ArraySetAsSeries(MA, true);
   ObjectCreate(0, "High", OBJ_HLINE, 0, 0, 0);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   //ATRHandler = iATR(_Symbol, PERIOD_D1, 300);
   MAHandler = iMA(_Symbol, PERIOD_D1, 100, 0, MODE_SMA, PRICE_CLOSE);
   
   Comment("ID: ", Magic);
   CheckPositions();
}

void OnTick(){
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {      
      R_Start = StringToTime(today+" "+Range_Start);
      R_End = StringToTime(today+" "+Range_End);
      T_Start = StringToTime(today+" "+Trade_Start);
      Exit = StringToTime(today+" "+Trade_Exit);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      //CopyBuffer(ATRHandler, 0, 0, 3, ATR);
      //CopyBuffer(MAHandler, 0, 0, 3, MA);
      yesterday=today;
      flag1=false;
      flag2=false;
   }


   newbar= iBars(_Symbol, Timeframe);
   if(bar1!=newbar){
      if(today!=yesterday2){
         if(TimeCurrent()>=T_Start && TimeCurrent()<Exit){
            Range();
            yesterday2=today;
         }
      }

      if(today!=yesterday3){
         if(TimeCurrent()>=Exit){
           ClosePosition(POSITION_TYPE_BUY);
           ClosePosition(POSITION_TYPE_SELL);
           yesterday3=today;            
         }
      }
      
      if(TimeCurrent()>=T_Start && TimeCurrent()<Exit){
         CheckPositions();
         CopyRates(_Symbol, Timeframe, 0, 3, Price);
         if((Highest-Lowest)>Price[1].close*.0015 && (Highest-Lowest)<Price[1].close*.0085 && (buyOrder+sellOrder)==0){
            open = NormalizeDouble((Highest-Lowest)/2, 2);
            if(Price[1].close<open-open*(retracement/100) && flag1==false)
               ExecuteBuyStop(Highest+15*_Point, NormalizeDouble(SlPer/100*Price[0].close, 2));
                 
            if(Price[1].close>open+open*(retracement/100) && flag2==false)
               ExecuteSellStop(Lowest-15*_Point, NormalizeDouble(SlPer/100*Price[0].close, 2));
         }       
               
         if(buyPosition>0){
            CloseOrder(ORDER_TYPE_SELL_STOP);
         }
         else if(sellPosition>0){
            CloseOrder(ORDER_TYPE_BUY_STOP);
         }
      }
      
      Comment(bar1);
      bar1=newbar;   
   }
}



//---------------------------------------------------------------------------------------------------------



void PositionSize(){
   if(FixedRisk>0){
      Lot = int((initial_balance*FixedRisk)/(NormalizeDouble(SlPer/100*Price[0].close, 2)));
   }
   else if(VariableRisk<=0){
      Lot = MinLot;
   }
   else{
      int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
      Lot = int((_rounded_balance*VariableRisk)/(NormalizeDouble(SlPer/100*Price[0].close, 2)));
      
   }
   
   if(Lot<MinLot) Lot=MinLot;
   if(Lot>1000) Lot=1000;
}

void ExecuteBuy(double slpoints=NULL, double tppoints=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   PositionSize();
   trade.Buy(Lot, _Symbol, Ask, slpoints, tppoints, text);
}

void ExecuteSell(double slpoints=NULL, double tppoints=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   PositionSize();
   trade.Sell(Lot, _Symbol, Bid, slpoints, tppoints, text);
}

void ExecuteBuyStop(double entry, double sl=NULL, double tp=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   double _sl = Ask-sl;
   //double _tp = Ask+tp;
   PositionSize();
   trade.BuyStop(Lot, entry, _Symbol, _sl, NULL, ORDER_TIME_SPECIFIED, Expiration, text);
   flag1=true;
   
}

void ExecuteSellStop(double entry, double sl=NULL, double tp=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry) return;
   double _sl = Bid+sl;
   //double _tp = Bid-tp;
   PositionSize();
   trade.SellStop(Lot, entry, _Symbol, _sl, NULL, ORDER_TIME_SPECIFIED, Expiration, text);
   flag2=true;
}

void CheckPositions(){     
   buyPosition=0;
   sellPosition=0;
   buyOrder=0;
   sellOrder=0;
   buyDuration = -1;
   sellDuration = -1;
   
   ulong _ticket;
   
   for(int i=0; i<OrdersTotal(); i++){
      _ticket = OrderGetTicket(i);
         
      if(OrderSelect(_ticket)){
         if(OrderGetInteger(ORDER_MAGIC) == Magic && OrderGetString(ORDER_SYMBOL) == _Symbol){
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT){
               buyOrder+=1;
            }
            else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP ||OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT){
               sellOrder+=1;
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
               buyDuration = iBarShift(_Symbol, PERIOD_D1, PositionGetInteger(POSITION_TIME), false);
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               sellPosition+=1;
               sellDuration = iBarShift(_Symbol, PERIOD_D1, PositionGetInteger(POSITION_TIME), false);
            }
         }
      }
   }
   
   //if(ArraySize(ATR)>1) Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\nATR: ", NormalizeDouble(ATR[1], 3));
   //else Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration);
}

void TimeExit(){
   if(buyDuration>=TimeExit1 && TimeExit1>=0) ClosePosition(POSITION_TYPE_BUY);
   if(sellDuration>=TimeExit2 && TimeExit2>=0) ClosePosition(POSITION_TYPE_SELL);
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

void Range(){
   CopyHigh(_Symbol, PERIOD_M5, R_Start, R_End, High);
   CopyLow(_Symbol, PERIOD_M5, R_Start, R_End, Low);
   
   if(ArraySize(High)>0 && ArraySize(Low)>0){
      Highest = High[ArrayMaximum(High, 0, WHOLE_ARRAY)];
      Lowest = Low[ArrayMinimum(Low, 0, WHOLE_ARRAY)];
      ObjectMove(0, "High", 0, _Period, Highest);
      ObjectMove(0, "Low", 0, _Period, Lowest);  
   }
}