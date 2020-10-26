//+------------------------------------------------------------------+
//|                                        Strategy: IdeaPro_Adv.mq4 |
//|                                          Created with David Chen |
//+------------------------------------------------------------------+
#property copyright "David"
#property version   "2.00"
#property description ""

#include <stdlib.mqh>
#include <stderror.mqh>

//External variables
extern int MagicNumber = 123;
extern int TakeProfit = 8;
extern int StopLoss = 5000;
extern int MaxSlippage = 10;

//initialize variales
int LotDigits; 
double OrderSetList[10][2];
int num;
int OrderRetry = 5; //# of retries if sending order returns error
int OrderWait = 5; //# of seconds to wait if sending order returns error


//+------------------------------------------------------------------+
//| Functions                                                        |
//+------------------------------------------------------------------+

//Alert function
void myAlert(string type, string message)
  {
   if(type == "print")
      Print(message);
   else if(type == "error")
     {
      Print(type+" | test2 @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
     }
   else if(type == "order")
     {
     }
   else if(type == "modify")
     {
     }
  }

//+------------------------------------------------------------------+
//| Calculate Lot size                                               |
//+------------------------------------------------------------------+
//Calculate Lot size
bool SelectLastCurrentTrade()
  {
   int lastOrder = -1;
   int total = OrdersTotal();
   //Count from last to most current
   for(int i = total-1; i >= 0; i--) // Select most current order, i is from total -1 to 0, array start from zero
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue; //Select from history, If function can not select order, skip the function.
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) //If they have same symbol and same magic number, record the number and finish the function
        {
         lastOrder = i;
         //Break if there is an order
         break;
        }
     }
  //return true if there is an live order
   return(lastOrder >= 0);
  }

int findTotalOrders()
  {
   int totalOrder = 0;
   int total = OrdersTotal();
   //Count from last to most current
   for(int i = total-1; i >= 0; i--) // Select most current order, i is from total -1 to 0, array start from zero
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue; //Select from history, If function can not select order, skip the function.
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) //If they have same symbol and same magic number, record the number and finish the function
        {
          totalOrder += 1;
        }
     }
  //return true if there is an live order
   return(totalOrder);
  }

double MM_Size() 
  {
   double lots = 0.01;
   if(findTotalOrders()>= 1)
   {
      lots =OrderSetList[findTotalOrders()][0];
   }
   return(lots);
  }

double Grid_Size() 
  {
   double grids = 8;
   if(findTotalOrders()>= 1)
   {
     grids = OrderSetList[findTotalOrders()][1];
     printf(grids);
   }
   return(grids);
  }


double findTotalProfit()
   {
     double Total_profit= 0;
     for(int cnt = 0; cnt <= OrdersTotal(); cnt++){
       //Select the order required
       if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) continue;
       if(OrderMagicNumber() != MagicNumber) continue;
       Total_profit += OrderProfit() + OrderSwap() + OrderCommission();
     }
     return Total_profit;
   }

//+------------------------------------------------------------------+
//| Determine Open & Close                                           |
//+------------------------------------------------------------------+


//Determine Buy Trades
bool determineOrder(int type)
{
 
 
 if(!SelectLastCurrentTrade())
 {
   return true;
 }
 
 
 //Add buy order if price going down
 if(SelectLastCurrentTrade())
 {
   //deternube Grid size
   int grid = Grid_Size();
 
   if (type == OP_BUY && OrderOpenPrice()- Ask >= 0.0001*grid)
   {
     return true;
   }
   if (type == OP_SELL && Bid - OrderOpenPrice() >= 0.0001*grid)
   {
      return true;
   }
 }
  return false;
}


//Determine Close

double determineClose()
{
  //Close orders base on profit
  double currentTotalProfit = findTotalProfit();
  int takeProfit = TakeProfit;

  SelectLastCurrentTrade();
  if(findTotalOrders() >= 8)
  {
    takeProfit = 0;
  }
  if(currentTotalProfit > takeProfit)
  {
   return true;
  }
  else if(findTotalProfit() > 150 || currentTotalProfit < -StopLoss)
  {
    return true;
  }
  return false;
}

//+------------------------------------------------------------------+
//| Open & Close Orders                                              |
//+------------------------------------------------------------------+
//Send Order
int myOrderSend(string symbol, int type, double price, double volume, string ordername) //send order, return ticket ("price" is irrelevant for market orders)
  {
   //Initialise
   if(!IsTradeAllowed()) return(-1);
   int ticket = -1;
   int retries = 0;
   int err = 0;
   string ordername_ = ordername;
   if (ordername_ != "")
   {
      ordername_="("+ordername+")";
   }

   //Prepare to send order
   while(IsTradeContextBusy()) Sleep(100);
   RefreshRates();
  //Alert Error if price is less than zero, invalid price for pending order
   if(price < 0)
     {
      myAlert("order", "Order"+ordername_+" not sent, invalid price for pending order");
	  return(-1);
     }
   int clr = (type % 2 == 1) ? clrRed : clrBlue;
  //Send Order, volume is autoMM
   while(ticket < 0 && retries < OrderRetry+1)
     {
      ticket = OrderSend(Symbol(),type, NormalizeDouble(volume, LotDigits), NormalizeDouble(price, Digits()), MaxSlippage, 0, 0, ordername, MagicNumber, 0, clr);
      //Prevent error
      if(ticket < 0)
        {
         err = GetLastError();
         myAlert("print", "OrderSend"+ordername_+" error #"+IntegerToString(err)+" "+ErrorDescription(err));
         Sleep(OrderWait*1000);
        }
      retries++;
     }
   if(ticket < 0)
     {
      myAlert("error", "OrderSend"+ordername_+" failed "+IntegerToString(OrderRetry+1)+" times; error #"+IntegerToString(err)+" "+ErrorDescription(err));
      return(-1);
     }
   string typestr[6] = {"Buy", "Sell", "Buy Limit", "Sell Limit", "Buy Stop", "Sell Stop"};
   myAlert("order", "Order sent"+ordername_+": "+typestr[type]+" "+Symbol()+" Magic #"+IntegerToString(MagicNumber));
   return(ticket);
  }

//Close all orders
void myOrderClose(int type, int volumepercent, string ordername) //close open orders for current symbol, magic number and "type" (OP_BUY or OP_SELL)
  {
   //Test is trade allow, system function
   if(!IsTradeAllowed()) return;
   if (type > 1)
     {
      myAlert("error", "Invalid type in myOrderClose");
      return;
     }
  //Initial ticket sucess, Total orders, Order List, Order count.
   bool success = false;
   int err = 0;
   string ordername_ = ordername;
   if (ordername_ != "")
   {
      ordername_="("+ordername+")";
   }

   int total = OrdersTotal();
   int orderList[][2];
   int orderCount = 0;
   int i;
   for(i = 0; i < total; i++)
     {
      while(IsTradeContextBusy()) Sleep(100);
      //Select the order required
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      //If the Magic number of the order is not the same, Skip if the symbol, magicnumber or type of order is not the same
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol() || OrderType() != type) continue;
      //Count all the orders
      orderCount++;
      //Resize array and add order list, assign ticket number to array list [1]
      ArrayResize(orderList, orderCount);
      orderList[orderCount - 1][0] = OrderOpenTime();
      orderList[orderCount - 1][1] = OrderTicket();
     }
  //Sort Array from 0, small to large
   if(orderCount > 0)
      ArraySort(orderList, WHOLE_ARRAY, 0, MODE_ASCEND);
  //Close Order
   for(i = 0; i < orderCount; i++)
     {
      //Select the orders in the order list
      if(!OrderSelect(orderList[i][1], SELECT_BY_TICKET, MODE_TRADES)) continue;
      while(IsTradeContextBusy()) Sleep(100);
      RefreshRates();
      //Assign price
      double price = (type == OP_SELL) ? Ask : Bid;
      //Around the volume to digit, use current lot size.
      double volume = NormalizeDouble(OrderLots()*volumepercent * 1.0 / 100, LotDigits);
      //if volume is zero, skip the order close process
      if (NormalizeDouble(volume, LotDigits) == 0) continue;
      //Order close
      success = OrderClose(OrderTicket(), volume, NormalizeDouble(price, Digits()), MaxSlippage, clrWhite);
      //If no ticket number return, alert error
      if(!success)
        {
         err = GetLastError();
         myAlert("error", "OrderClose"+ordername_+" failed; error #"+IntegerToString(err)+" "+ErrorDescription(err));
        }
     }
  }


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {   
  //initialize LotDigits
   double LotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   if(LotStep >= 1) LotDigits = 0;
   else if(LotStep >= 0.1) LotDigits = 1;
   else if(LotStep >= 0.01) LotDigits = 2;
   else LotDigits = 3;

   //initialize order set lot
   OrderSetList[0] = 0.01;
   OrderSetList[1] = 0.01;
   OrderSetList[2] = 0.02;
   OrderSetList[3] = 0.03;
   OrderSetList[4] = 0.05;
   OrderSetList[5] = 0.08;
   OrderSetList[6] = 0.13;
   OrderSetList[7] = 0.13;
   OrderSetList[8] = 0.13;
   OrderSetList[9] = 0.13;

   //initialize order set grid
   OrderSetList[0][1] = 8;
   OrderSetList[1][1] = 14;
   OrderSetList[2][1] = 20;
   OrderSetList[3][1] = 28;
   OrderSetList[4][1] = 38;
   OrderSetList[5][1] = 51;
   OrderSetList[6][1] = 68;
   OrderSetList[7][1] = 98;
   OrderSetList[8][1] = 138;
   OrderSetList[9][1] = 218;
   
   //Initialise num
   num = rand()%10+1;
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   int ticket = -1;
   double price;   
   bool buyTrade = false;
   bool sellTrade = false;
   bool closeTrade = false;
   
   if( num > 5)
   {
      buyTrade = determineOrder(OP_BUY);
   }
   else if( num <= 5)
   {
      sellTrade = determineOrder(OP_SELL);
   }
   
   closeTrade = determineClose();

   //Close All Positions
   if(closeTrade) //Close order and take profit, if Profit > Set Amount. 
     {   
      RefreshRates();
      if(IsTradeAllowed())
         myOrderClose(OP_SELL, 100, "");
         myOrderClose(OP_BUY, 100, "");
         num = rand()%10+1;
     }
   
   //Open Buy Order, instant signal is tested first
   if(buyTrade) //Moving Average crosses above Moving Average
     {
      RefreshRates();
      price = Ask;   
      if(IsTradeAllowed())
        {
         int ticket1 = myOrderSend("EURUSD",OP_BUY, price, MM_Size(), "");
         //int ticket2 = myOrderSend("AUDUSD",OP_SELL, price, MM_Size(), "");
         //int ticket3 = myOrderSend("EURJPY",OP_SELL, price, MM_Size(), "");
         //int ticket4 = myOrderSend("NZDUSD",OP_SELL, price, MM_Size(), "");
         //int ticket5 = myOrderSend("USDJPY",OP_SELL, price, MM_Size(), "");
         //if(ticket1 <= 0 || ticket2 <= 0 || ticket3 <= 0 || ticket4 <= 0 || ticket5 <= 0) return;
        }
      else //not autotrading => only send alert
         myAlert("order", "");
     }
    

   //Open Sell Order, instant signal is tested first
   if(sellTrade) //Moving Average crosses above Moving Average
     {
      RefreshRates();
      price = Bid;
      if(IsTradeAllowed())
        {
         ticket1 = myOrderSend("EURUSD",OP_SELL, price, MM_Size(), "");
         //ticket2 = myOrderSend("AUDUSD",OP_BUY, price, MM_Size(), "");
         //ticket3 = myOrderSend("EURJPY",OP_BUY, price, MM_Size(), "");
         //ticket4 = myOrderSend("NZDUSD",OP_BUY, price, MM_Size(), "");
         //ticket5 = myOrderSend("USDJPY",OP_BUY, price, MM_Size(), "");
         //if(ticket1 <= 0 || ticket2 <= 0 || ticket3 <= 0 || ticket4 <= 0 || ticket5 <= 0) return;
        }
      else //not autotrading => only send alert
         myAlert("order", "");
     }

   }
//+------------------------------------------------------------------+