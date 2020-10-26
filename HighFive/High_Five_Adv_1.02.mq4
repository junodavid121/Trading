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
extern int TakeProfit = 150;
extern int TakeProfit_pip = 8;
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

//----------------------------------------------------------------------------------------------
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

//----------------------------------------------------------------------------------------------
//Identify Last Current Trade
bool SelectLastCurrentTrade()
  {
   int lastOrder = -1;
   int total = OrdersTotal();
   for(int i = total-1; i >= 0; i--) 
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;  
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) 
        {
         lastOrder = i;
         break;
        }
     }
   return(lastOrder >= 0);
  }

//----------------------------------------------------------------------------------------------
//Identify Number of Orders
int findNumberOfOrders()
  {
   int totalOrder = 0;
   int total = OrdersTotal();
   for(int i = total-1; i >= 0; i--) 
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue; 
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) 
        {
          totalOrder += 1;
        }
     }
   return(totalOrder);
  }

//----------------------------------------------------------------------------------------------
//Determine Lot size
double MM_Size() 
  {
   double lots = 0.01;
   else if(findNumberOfOrders() == 9)
   {
     lot = 0.13
   }
   else if(findNumberOfOrders() == 8)
   {
     lot = 0.13
   }
   else if(findNumberOfOrders() == 7)
   {
     lot = 0.13
   }
   else if(findNumberOfOrders() == 6)
   {
     lot = 0.13
   }
   else if(findNumberOfOrders() == 5)
   {
     lot = 0.8
   }
   else if(findNumberOfOrders() == 4)
   {
     lot = 0.5
   }
   else if(findNumberOfOrders() == 3)
   {
     lot = 0.3
   }
   else if(findNumberOfOrders() == 2)
   {
     lot = 0.2
   }
   else if(findNumberOfOrders() == 1)
   {
     lot = 0.01
   }
   return(lots);
  }


//----------------------------------------------------------------------------------------------
//Find total Profit
double findTotalProfit()
   {
     double Total_profit= 0;
     for(int cnt = 0; cnt <= OrdersTotal(); cnt++){
       if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) continue;
       if(OrderMagicNumber() != MagicNumber) continue;
       Total_profit += OrderProfit() + OrderSwap() + OrderCommission();
     }
     return Total_profit;
   }

//----------------------------------------------------------------------------------------------
//Find total Lots
double findTotalLots()
   {
     double Total_lot= 0;
     for(int cnt = 0; cnt <= OrdersTotal(); cnt++){
       if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES)) continue;
       if(OrderMagicNumber() != MagicNumber) continue;
       Total_lot += OrderLots();
     }
     return Total_lot;
   }

//----------------------------------------------------------------------------------------------
// Calculate Average  price
double PriceAverage(int type)
{
   double PriceSum =0;
   double LotSum =0;
   int count=0;

   for (int i=0; i<OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))continue;
      if(OrderSymbol()==Symbol() && OrderType()== type && OrderMagicNumber() == MagicNumber)
      {
         PriceSum += OrderOpenPrice()*OrderLots();
         LotSum += OrderLots();
         count++;
      }
   }
   return(NormalizeDouble((PriceSum)/(LotSum),Digits));
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
  double myPoint = Point();
  if(Digits() == 5 || Digits() == 3)
    {
    myPoint *= 10;
    MaxSlippage *= 10;
    }   
  //initialize LotDigits
   double LotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   if(LotStep >= 1) LotDigits = 0;
   else if(LotStep >= 0.1) LotDigits = 1;
   else if(LotStep >= 0.01) LotDigits = 2;
   else LotDigits = 3;
   
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

   // Start New Order
   if(!SelectLastCurrentTrade())
   {
      if( num > 5)
      {
        buyTrade = true;
      }
      else if( num <= 5)
      {
        sellTrade = true;
      }
   }
   
  //If there is an existing orders, need to add order
  else if(SelectLastCurrentTrade())
  {
    //Add buy order if price going down in pips
    if(OrderType() == OP_BUY)
    {
      if(findNumberOfOrders() == 1 &&  Bid - PriceAverage(OP_BUY) > 8* myPoint) buyTrade = true;
      if(findNumberOfOrders() == 2 &&  Bid - PriceAverage(OP_BUY) > 14* myPoint) buyTrade = true;
      if(findNumberOfOrders() == 3 &&  Bid - PriceAverage(OP_BUY) > 28* myPoint) buyTrade = true;
      if(findNumberOfOrders() == 4 &&  Bid - PriceAverage(OP_BUY) > 38* myPoint) buyTrade = true;
      if(findNumberOfOrders() == 5 &&  Bid - PriceAverage(OP_BUY) > 51* myPoint) buyTrade = true;
      if(findNumberOfOrders() == 6 &&  Bid - PriceAverage(OP_BUY) > 68* myPoint) buyTrade = true;
      if(findNumberOfOrders() == 7 &&  Bid - PriceAverage(OP_BUY) > 98* myPoint) buyTrade = true;
      if(findNumberOfOrders() == 8 &&  Bid - PriceAverage(OP_BUY) > 138* myPoint) buyTrade = true;
      if(findNumberOfOrders() == 9 &&  Bid - PriceAverage(OP_BUY) > 218* myPoint) buyTrade = true;
      if(findNumberOfOrders() == 10 &&  Bid - PriceAverage(OP_BUY) > 335* myPoint) buyTrade = true;
      buyTrade = false; 
    }
    //Add sell order if price going up in pips
    if(OrderType() == OP_SELL)
    {
      if(findNumberOfOrders() == 1 &&  PriceAverage(OP_SELL) - Ask > 8* myPoint) sellTrade = true;
      if(findNumberOfOrders() == 2 &&  PriceAverage(OP_SELL) - Ask > 14* myPoint) sellTrade = true;
      if(findNumberOfOrders() == 3 &&  PriceAverage(OP_SELL) - Ask > 28* myPoint) sellTrade = true;
      if(findNumberOfOrders() == 4 &&  PriceAverage(OP_SELL) - Ask > 38* myPoint) sellTrade = true;
      if(findNumberOfOrders() == 5 &&  PriceAverage(OP_SELL) - Ask > 51* myPoint) sellTrade = true;
      if(findNumberOfOrders() == 6 &&  PriceAverage(OP_SELL) - Ask > 68* myPoint) sellTrade = true;
      if(findNumberOfOrders() == 7 &&  PriceAverage(OP_SELL) - Ask > 98* myPoint) sellTrade = true;
      if(findNumberOfOrders() == 8 &&  PriceAverage(OP_SELL) - Ask > 138* myPoint) sellTrade = true;
      if(findNumberOfOrders() == 9 &&  PriceAverage(OP_SELL) - Ask > 218* myPoint) sellTrade = true;
      if(findNumberOfOrders() == 10 &&  PriceAverage(OP_SELL) - Ask > 335* myPoint) sellTrade = true;
      sellTrade = false; 
    }
  }
  
  //Open new Buy Order if there is a new order requirement
  if(buyTrade) 
    {
    RefreshRates();
    price = Ask;   
    if(IsTradeAllowed())
      {
        //Add 5 trades
        int ticket1 = myOrderSend("EURUSD",OP_BUY, price, MM_Size(), "");
        //int ticket2 = myOrderSend("AUDUSD",OP_SELL, price, MM_Size(), "");
        //int ticket3 = myOrderSend("EURJPY",OP_SELL, price, MM_Size(), "");
        //int ticket4 = myOrderSend("NZDUSD",OP_SELL, price, MM_Size(), "");
        //int ticket5 = myOrderSend("USDJPY",OP_SELL, price, MM_Size(), "");
        //if(ticket1 <= 0 || ticket2 <= 0 || ticket3 <= 0 || ticket4 <= 0 || ticket5 <= 0) return;
      }
    else 
        myAlert("order", "");
    }

  //Open new Sell Order if there is a new order requirement
  if(sellTrade) 
    {
    RefreshRates();
    price = Bid;
    if(IsTradeAllowed())
      {
        //Add 5 trades
        ticket1 = myOrderSend("EURUSD",OP_SELL, price, MM_Size(), "");
        //ticket2 = myOrderSend("AUDUSD",OP_BUY, price, MM_Size(), "");
        //ticket3 = myOrderSend("EURJPY",OP_BUY, price, MM_Size(), "");
        //ticket4 = myOrderSend("NZDUSD",OP_BUY, price, MM_Size(), "");
        //ticket5 = myOrderSend("USDJPY",OP_BUY, price, MM_Size(), "");
        //if(ticket1 <= 0 || ticket2 <= 0 || ticket3 <= 0 || ticket4 <= 0 || ticket5 <= 0) return;
      }
    else
        myAlert("order", "");
    }

  //Deteremine Close trades

  if(SelectLastCurrentTrade())
  {
    //If total profit in pip higher than 8 pip, Take Profit
    if (findTotalProfit()/findTotalLots()>= TakeProfit_pip*myPoint) return true;
    //If total number of order more than 8, change take profit to 0
    if(findNumberOfOrders() >= 8)
    {
      TakeProfit = 0;
    }
    //If total profit > 150, take profit
    if(findTotalProfit() >= TakeProfit)
    {
    return true;
    }
    // Stop Loss
    if(findTotalProfit() < -StopLoss)
    {
      return true;
    }
    return false;
  }

  //Close All Positions
  if(closeTrade) //Close order and take profit, if Profit > Set Amount. 
    {   
    RefreshRates();
    if(IsTradeAllowed())
        // Close all orders in different currency
        myOrderClose(OP_SELL, 100, "");
        myOrderClose(OP_BUY, 100, "");
        num = rand()%10+1;
    }

}
//+------------------------------------------------------------------+
