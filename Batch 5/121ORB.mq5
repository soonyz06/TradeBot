#include<Trade\Trade.mqh>
CTrade trade;

input group "===   Inputs   ===";
input ulong Magic = 121;
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input double FixedRisk = 0.01;
input double VariableRisk = 0;
input double MinLot = 0.1;
double Lot;
double initial_balance;
input string Note = "";

input group "===   Settings   ===";
input double TpATR1 = 2.5; //TP
input double SlATR = 0.5; //SL
input int TimeExit1 = 5; //Time Exit 
double TriggerATR = 0;
input double Entry = -1; //Entry
input int std_len = 60; //STD Length
input int Mode = 0;
input bool Delay = false;
int atr_len; //ATR Length
double TpATR2 = TpATR1; 
int TimeExit2= TimeExit1;

input group "===   Time   ===";
input int A = 17; //Start Time 
int B; 
int Z; 
int E; 
//16:30-23:00

//Variables
string today;
string yesterday;
string yesterday2;
string yesterday3;
string yesterday4;
datetime Start;
datetime Stop;
datetime Exit;
datetime Expiration;
datetime Filter;
datetime Filter2;
string Trade_Start; 
string Trade_Stop; 
string Trade_Exit; 
string Trade_Expiration; 
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
double Highest = 0;
double Lowest = DBL_MAX;
double oldHigh;
double oldLow;
double ATR[];
int ATRHandler;
double STD[];
int STDHandler;
double POI;
double Close[];



//---------------------------------------------------------------------------------------------------------



void OnInit(){
   atr_len = 50;
   B = 22; //Stop Time
   Z = 16; //Exit Time
   E = 18; //Expiration Time
   Trade_Start= string(A)+":00:00"; //Start Time
   Trade_Stop = string(B)+":55:00"; //Stop Time
   Trade_Exit = string(Z)+":35:00"; //Exit Time
   Trade_Expiration = string(E)+":00:00"; //Expiration Time
   buyDuration =-1;
   sellDuration =-1;
   
   trade.SetExpertMagicNumber(Magic);
   text = string(Magic);
   bar1=0;
   bar2=0;
   yesterday="";
   yesterday2="";
   yesterday3="";
   yesterday4="";
   initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   ArraySetAsSeries(ATR, true);
   ArraySetAsSeries(STD, true);
   ObjectCreate(0, "High", OBJ_HLINE, 0, 0, 0);
   ObjectCreate(0, "Base", OBJ_HLINE, 0, 0, 0);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Base", OBJPROP_COLOR, clrLightGray);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   ATRHandler = iATR(_Symbol, PERIOD_D1, atr_len);
   STDHandler = iStdDev(_Symbol, Timeframe, std_len, 0, MODE_SMA, PRICE_CLOSE);
   Comment("ID: ", Magic);
   CheckPositions();
   Stop = StringToTime(TimeToString(TimeCurrent(), TIME_DATE)+" "+Trade_Stop);
}

void OnTick(){
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {     
      Start = StringToTime(today+" "+"16:45:00");
      Exit = StringToTime(today+" "+Trade_Exit);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      Filter = StringToTime(today+" "+"16:00:00");
      Filter2 = StringToTime(today+" "+Trade_Start);
      CopyBuffer(ATRHandler, 0, 0, 3, ATR);
      yesterday=today;
   }

   newbar= iBars(_Symbol, Timeframe);
   if(bar2!=newbar){
      if(TimeCurrent()>=Exit){
         if(today!=yesterday3){
            TimeExit();
            CheckPositions();
            yesterday3 = today;
         }
      }
      
      if(TimeCurrent()>=Filter){
         if(today!=yesterday4){
            CopyRates(_Symbol, Timeframe, Stop, 3, Price);
            AppendToArray(Price[0].close);  
            if(Mode==1) GetEntry(Price[0].close);
            Stop = StringToTime(today+" "+Trade_Stop);
            yesterday4 = today;
         }
      }
      
      CopyRates(_Symbol, Timeframe, 0, 4, Price);
      
      if(TimeCurrent()>Start && TimeCurrent()<Stop){ //17-22
         AppendToArray(Price[1].close);
      }
      bar2=newbar;
   }
   
   if(bar1!=newbar){
      if(TimeCurrent()>=Start && TimeCurrent()<Stop){
         if(Mode==0) GetEntry(iOpen(Symbol(), Timeframe, 0));
         CheckPositions();
         if(buyPosition==0 && ArraySize(Close)==3 && ((Delay==false && Close[1]<POI && Close[2]>POI) || (Delay==true && Close[0]<POI && Close[1]>POI)) && (ATR[1]!=0 && ATR[1]<1000) && TimeCurrent()>=Filter2){
         //if(buyPosition==0 && ((Delay==false && Price[2].close<POI && Price[1].close>POI) || (Delay==true && Price[3].close<POI && Price[2].close>POI)) && (ATR[1]!=0 && ATR[1]<1000) && TimeCurrent()>=Filter2){
            ExecuteBuy();
            //SendNotification("Buy"+string(_Symbol));
         }
         bar1=newbar;
      } 
      
      //entry=exit
   }
   
   
}



//---------------------------------------------------------------------------------------------------------



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

void ExecuteBuy(double slpoints=NULL, double tppoints=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(tppoints==NULL && TpATR1>0) tppoints = Ask+TpATR1*ATR[1];
   if(slpoints==NULL && SlATR>0) slpoints = Ask-SlATR*ATR[1];
   
   PositionSize();
   trade.Buy(Lot, _Symbol, Ask, slpoints, tppoints, text);
}

void ExecuteSell(double slpoints=NULL, double tppoints=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(tppoints==NULL && TpATR2>0) tppoints = Bid-TpATR2*ATR[1];
   if(slpoints==NULL && SlATR>0) slpoints = Bid+SlATR*ATR[1];
   
   PositionSize();
   trade.Sell(Lot, _Symbol, Bid, slpoints, tppoints, text);
}

void ExecuteBuyOrder(double entry, double sl=NULL, double tp=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry && Entry>0) return;
   if(Ask<entry && Entry<0) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlATR>0) _sl=entry-SlATR*ATR[1];
   if(tp==NULL && TpATR1>0) _tp=entry+TpATR1*ATR[1];
   PositionSize();
   trade.BuyStop(Lot, entry, _Symbol, _sl, _tp, ORDER_TIME_SPECIFIED, Expiration, text);
}

void ExecuteSellStop(double entry, double sl=NULL, double tp=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlATR>0) _sl=entry+SlATR*ATR[1];
   if(tp==NULL && TpATR2>0) _tp=entry-TpATR2*ATR[1];
   PositionSize();
   trade.SellStop(Lot, entry, _Symbol, _sl, _tp, ORDER_TIME_SPECIFIED, Expiration, text);
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
               buyDuration = iBarShift(_Symbol, PERIOD_D1, PositionGetInteger(POSITION_TIME), false);
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               sellPosition+=1;
               sellDuration = iBarShift(_Symbol, PERIOD_D1, PositionGetInteger(POSITION_TIME), false);
            }
         }
      }
   }
   
   if(ArraySize(ATR)>1) Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\nATR: ", NormalizeDouble(ATR[1], 3), "\n", Note);
   else Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\n", Note);
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
               TriggerATR=TpATR1;
            }
            else{
               _profitMargin = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
               TriggerATR=TpATR2;
            }
            
            if(type == PositionGetInteger(POSITION_TYPE) && _profitMargin>TriggerATR*ATR[1]){
               return true;
            }
         }
      }
   }
   return false;
}

void ProcessPosition(){ 
   //if(TriggerATR<0) return;
   return;
   
   if(InProfit(POSITION_TYPE_BUY)){
      ClosePosition(POSITION_TYPE_BUY);
   }
   if(InProfit(POSITION_TYPE_SELL)){
      ClosePosition(POSITION_TYPE_SELL);
   }
}

void Range(int bars){
   if(bars<=0) return; 
   
   Highest = iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH, bars, 2));
   Lowest = iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, bars, 2));
   
   if(Highest!=oldHigh){
      ObjectMove(0, "High", 0, 0, Highest);
      oldHigh = Highest;
   }
   if(Lowest!=oldLow){
      ObjectMove(0, "Low", 0, 0, Lowest);
      oldLow = Lowest; 
   }
}

void AppendToArray(double value){
    ArrayResize(Close, ArraySize(Close) + 1);
    Close[ArraySize(Close) - 1] = value;
    if(ArraySize(Close)==4){
      for (int i = 1; i < ArraySize(Close); i++) {
        Close[i - 1] = Close[i];
       }
       ArrayResize(Close, ArraySize(Close) - 1);
    }
    
    //Print(TimeCurrent());
    //if(ArraySize(Close)>0){
    //  for (int i = 0; i < ArraySize(Close); i++) {
    //    Print("Close[", i, "]: ", Close[i]);
    //  }
    //}
}

void GetEntry(double price){
   if(today!=yesterday2){
      CopyBuffer(STDHandler, 0, 0, 3, STD);    
      POI = price+Entry*STD[0]; 
      Lowest = price-MathAbs(Entry)*STD[0];
      Highest = price+MathAbs(Entry)*STD[0];
      ObjectMove(0, "Low", 0, _Period, Lowest); 
      ObjectMove(0, "Base", 0, _Period, price); 
      ObjectMove(0, "High", 0, _Period, Highest); 
      yesterday2=today;
   }
}