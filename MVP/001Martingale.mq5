#include<Trade\Trade.mqh>
CTrade trade;

input group "===   Inputs   ===";
input ulong Magic = 001;
input ENUM_TIMEFRAMES Timeframe = PERIOD_D1;
input double _R = 1; //FixedRisk
double FixedRisk;
double VariableRisk;
double MinLot;
double Lot;
double initial_balance;
input string Note = "";

input group "===   Settings   ===";
input double Value = 0; //Intrinsic value
input double Distance = 0.2; //Distance 
input int F = 2; //Multiplier

input group "===   Time   ===";
int A = 16; //Start Time
int B; //Stop Time
int Z; //Exit Time
int E; //Expiration Time
//16:30-23:00

//Variables
string today;
string yesterday;
string yesterday2;
datetime Start;
datetime Stop;
datetime Exit;
datetime Expiration;
string Trade_Start; //Start Time
string Trade_Stop; //Stop Time
string Trade_Exit; //Exit Time
string Trade_Expiration; //Expiration Time
int bar1;
int bar2;
int newbar;
string text;
int buyPosition;
int sellPosition;
int buyDuration;
int sellDuration;
int buyOrder;
int sellOrder;

MqlRates Price[];
double BuyPOI = 0;
double SellPOI = 0;
double POI = 0;

//---------------------------------------------------------------------------------------------------------



void OnInit(){
   FixedRisk = _R/100;
   VariableRisk = 0;
   MinLot = 0.1;
   
   Z = 17; //Exit Time
   B = 22; //Stop Time
   E = 18; //Expiration Time
   Trade_Start= string(A)+":55:00"; 
   Trade_Stop = string(B)+":55:00"; 
   Trade_Exit = string(Z)+":00:00"; 
   Trade_Expiration = string(E)+":00:00"; 
   buyDuration =-1;
   sellDuration =-1;
   
   trade.SetExpertMagicNumber(Magic);
   text = string(Magic);
   bar1=0;
   bar2=0;
   yesterday="";
   yesterday2="";
   initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ArraySetAsSeries(Price, true);
   ObjectCreate(0, "Intrinsic Value", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "Intrinsic Value", OBJPROP_COLOR, clrWhite);
   Comment("ID: ", Magic);
   CheckPositions();
   Stop = StringToTime(TimeToString(TimeCurrent(), TIME_DATE)+" "+Trade_Stop); 
   if(Value==0) POI = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   else POI = Value;
   ObjectMove(0, "Intrinsic Value", 0, 0, POI);
}

void OnTick(){
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Exit = StringToTime(today+" "+Trade_Exit);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      CheckPositions();
      yesterday=today;
   }

   newbar= iBars(_Symbol, Timeframe);
   if(bar1!=newbar){
      if(TimeCurrent()>=Start){
         CopyRates(_Symbol, Timeframe, 0, 3, Price);
         CheckPositions();
         
         //Reset Orders
         if(buyPosition<=0) CloseOrder(ORDER_TYPE_BUY_LIMIT);
         if(sellPosition<=0) CloseOrder(ORDER_TYPE_SELL_LIMIT);
         PositionSize();
         CheckPositions();
         
         //No Positons
         if(buyOrder+buyPosition<=0) ExecuteBuyLimit(NormalizeDouble(POI*(1-Distance), 3), int(MathPow(F, buyPosition)));
         if(sellOrder+sellPosition<=0) ExecuteSellLimit(NormalizeDouble(POI*(1+Distance), 3), int(MathPow(F, sellPosition)));
         CheckPositions();
         
         //Opened Positions
         if(buyOrder<=0 && buyPosition>0) ExecuteBuyLimit(NormalizeDouble(BuyPOI*(1-Distance), 3), int(MathPow(F, buyPosition)));
         if(sellOrder<=0 && sellPosition>0) ExecuteSellLimit(NormalizeDouble(SellPOI*(1+Distance), 3), int(MathPow(F, sellPosition)));
         
         bar1=newbar;
      }
   }
}



//---------------------------------------------------------------------------------------------------------



void PositionSize(){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(VariableRisk<=0 && FixedRisk<=0){
      Lot = MinLot;
   }
   else if(FixedRisk>0){
      Lot = MathRound((initial_balance*FixedRisk)/(Ask)/MinLot)*MinLot;
   }
   else{
      int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
      Lot = MathRound((_rounded_balance*VariableRisk)/(Ask)/MinLot)*MinLot;
   }
   if(Lot<MinLot) Lot=MinLot;
   if(Lot>1000) Lot=1000;
   
   Lot = NormalizeDouble(Lot, 2);
}


void CheckPositions(){     
   buyPosition=0;
   sellPosition=0;
   buyDuration = -1;
   sellDuration = -1;
   buyOrder=0;
   sellOrder=0;
   
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
               BuyPOI = PositionGetDouble(POSITION_PRICE_OPEN);
               buyDuration = iBarShift(_Symbol, PERIOD_D1, PositionGetInteger(POSITION_TIME), false);
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               sellPosition+=1;
               SellPOI = PositionGetDouble(POSITION_PRICE_OPEN);
               sellDuration = iBarShift(_Symbol, PERIOD_D1, PositionGetInteger(POSITION_TIME), false);
            }
         }
      }
   }
   
   Comment("ID: ", Magic, "\nIntrinsic Value: ", int(POI), "\nDistance: ", int(Distance*100),"%");
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

void ExecuteBuyLimit(double entry, double mult=1){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask<entry){
      entry = Price[0].low-10*_Point;
   }

   BuyPOI = entry;
   trade.BuyLimit(NormalizeDouble(Lot*mult, 2), entry, _Symbol, NULL, POI, NULL, NULL, text);
}

void ExecuteSellLimit(double entry, double mult=1){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid>entry){
      entry = Price[0].high+10*_Point;
   }
   Print("s");
   SellPOI = entry;
   trade.SellLimit(NormalizeDouble(Lot*mult, 2), entry, _Symbol, NULL, POI, NULL, NULL, text);
}