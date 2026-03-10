#include<Trade\Trade.mqh>
CTrade trade;

input group "===   Inputs   ===";
input ulong Magic = 129;
input ENUM_TIMEFRAMES Timeframe = PERIOD_MN1;
input double _R = 1; //FixedRisk
double FixedRisk;
double VariableRisk;
double MinLot;
double Lot;
int Mode;
double initial_balance;
input string Note = "";

input group "===   Settings   ===";
double TpATR1 = -1; //TP
double SlATR = -1; //SL
input double level1 = 5; //%
input double level2 = 10; //%
//input double level3 = 1; //%
input int TimeExit1 = 1; //Time Exit
int atr_len;

input group "===   Time   ===";
input int A = 16; //Start Time
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
datetime Filter;
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
double TriggerATR;

MqlRates Price[];
double ATR[];
int ATRHandler;
double _total;
double POI;


//---------------------------------------------------------------------------------------------------------



void OnInit(){
   FixedRisk = _R/100;
   VariableRisk = 0;
   MinLot = 0.1;
   POI = DBL_MAX;
   
   TpATR1 = -1;
   SlATR = -1;
   TriggerATR = 0;
   atr_len = 10;
   Z = 22; //Exit Time
   B = 22; //Stop Time
   E = B; //Expiration Time
   Trade_Start= string(A)+":55:00"; 
   Trade_Stop = string(B)+":55:00"; 
   Trade_Exit = string(Z)+":00:00"; 
   Trade_Expiration = string(E)+":00:00"; 
   buyDuration =-1;
   sellDuration =-1;
   Mode = 0;
   
   trade.SetExpertMagicNumber(Magic);
   text = string(Magic);
   bar1=0;
   bar2=0;
   yesterday="";
   yesterday2="";
   initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(ATR, true);
   //ATRHandler = iATR(_Symbol, PERIOD_D1, atr_len);
   Comment("ID: ", Magic);
   CheckPositions();
}

void OnTick(){
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
      //CopyBuffer(ATRHandler, 0, 0, 3, ATR);
      yesterday=today;
   }


   newbar = iBars(_Symbol, Timeframe);
   if(bar1!=newbar){ 
      if(TimeCurrent()>=Start && TimeCurrent()<Stop){
         //ProcessPosition();
         TimeExit();
         CopyRates(_Symbol, Timeframe, 0, 2, Price);
         CheckPositions();
         _total = level1+level2;
         if(((Price[1].close/Price[1].open)-1)*100 < -level1 && level1>0)// && 1-(Price[1].close/POI)>(0/100))
            ExecuteBuy(level1/_total);
         if(((Price[1].close/Price[1].open)-1)*100 < -level2 && level2>0)// && 1-(Price[1].close/POI)>(0/100))
            ExecuteBuy(level2/_total);
//         
         //if(((Price[1].close/Price[1].open)-1)*100 > 30){
         //   ClosePosition(POSITION_TYPE_BUY);
         //}
         bar1=newbar;
      }
   }
}



//---------------------------------------------------------------------------------------------------------



void PositionSize(double mult=1){
   if(VariableRisk<=0 && FixedRisk<=0){
      Lot = MinLot;
   }
   
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(FixedRisk>0){
      Lot = MathRound((initial_balance*FixedRisk)/(Ask)*mult/MinLot)*MinLot;
   }
   else{
      int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
      Lot = MathRound((_rounded_balance*VariableRisk)/(Ask)*mult/MinLot)*MinLot;
   }
   if(Lot<MinLot) Lot=MinLot;
   if(Lot>1000) Lot=1000;
}

void ExecuteBuy(double mult=1, double slpoints=NULL, double tppoints=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(tppoints==NULL && Mode==0 && TpATR1>0) tppoints = Ask+TpATR1*ATR[1];
   if(slpoints==NULL && SlATR>0) slpoints = Ask-SlATR*ATR[1];
   PositionSize(mult);
   trade.Buy(Lot, _Symbol, Ask, slpoints, tppoints, text);
   POI = Ask;
}

void ExecuteSell(double slpoints=NULL, double tppoints=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(tppoints==NULL && Mode==0 && TpATR1>0) tppoints = Bid-TpATR1*ATR[1];
   if(slpoints==NULL && SlATR>0) slpoints = Bid+SlATR*ATR[1];
   
   PositionSize();
   trade.Sell(Lot, _Symbol, Bid, slpoints, tppoints, text);
}

void CheckPositions(){     
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
   if(ArraySize(ATR)>1) Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\nATR: ", NormalizeDouble(ATR[1], 3), "\n", Note);
   else Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\n", Note);
}

void TimeExit(){
   if(buyDuration>=TimeExit1 && TimeExit1>=0) ClosePosition(POSITION_TYPE_BUY);
   if(sellDuration>=TimeExit1 && TimeExit1>=0) ClosePosition(POSITION_TYPE_SELL);
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
            }
            else{
               _profitMargin = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
            }
            
            if(type == PositionGetInteger(POSITION_TYPE) && _profitMargin>0){
               return true;
            }
         }
      }
   }
   return false;
}

void ProcessPosition(){
   if(InProfit(POSITION_TYPE_BUY)){
      ClosePosition(POSITION_TYPE_BUY);
   }
   if(InProfit(POSITION_TYPE_SELL)){
      ClosePosition(POSITION_TYPE_SELL);
   }
}