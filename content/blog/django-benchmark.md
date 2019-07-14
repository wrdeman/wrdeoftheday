---
title: "Django Benchmark"
date: 2019-02-02T21:18:24Z
draft: false
---

## Concurrency, Django and Apache Bench

The motivation for this blog was as a starting point in debugging errors caused errors caused by concurrency or race conditions - the so-called [Heisenbug](https://en.wikipedia.org/wiki/Heisenbug). I am going to use a contrived example of a bank account with a method to withdraw money and record each transaction. Then I will make a number of concurrent requests and investigate any undesired effects. I do not, in this blog, seek to propose any solution to these effects - solely to provide a means of determining whether they are present. 

The app for this demo can be found [here](https://github.com/wrdeman/demo-concurrency).

### Django App

For this task I will use a simple Django App with Session Authentication, a GET endpoint for retrieving the account balance, and a POST endpoint for making a withdrawl. I have chosen to use a POST request for the withdrawl method to illustrate how to use Apache Bench (Ab) with cookies.

#### Models
The simple account model is associated to a user, has a minimum and the current balance. The transaction model is used as a record the balance at each transaction from the account.


```Python
from django.contrib.auth.models import User                                    
from django.db import models                                                   
                                                                               
                                                                               
class Account(models.Model):                                                   
    user = models.ForeignKey(User, models.SET_NULL, null=True, blank=True)     
    minimum = models.IntegerField(default=0)                                 
    current = models.IntegerField(default=1000000)                             
                                                                              
    def make_withdrawl(self, value=1):                                         
        if self.current >= self.minimum:                                     
            self.current -= value                                              
            self.save()                                                        
        return self.current                                                    
                                                                              
                                                                               
class Transaction(models.Model):                                               
    holder = models.ForeignKey(Account, models.SET_NULL, null=True, blank=True)
    transaction = models.IntegerField()                                        
    balance = models.IntegerField()                                        
```

#### Views 
The views are really basic. The GET simply returns the current balance. The POST makes a withdrawl (default 1) and then creates the transaction.
```

from django.http import HttpResponse                                           
from django.views import View                                                  
from .models import Account, Transaction                                       
                                                                               
                                                                                          
class WithdrawView(View):                                                         
    def get(self, request, *args, **kwargs):                                   
        if request.user.is_authenticated:                                      
            holder = Account.objects.filter(user=request.user).first()         
            current = holder.current                                            
            return HttpResponse(current)                                                       
        return HttpResponse("")                                                
                                                                               
    def post(self, request, *args, **kwargs):                                                    
        holder = Account.objects.filter(user=request.user).first()             
        current = holder.make_withdrawl()                                      
        Transaction.objects.create(                                            
            holder=holder,                                                     
            transaction=current                                                
        )                                                                      
        return HttpResponse(current)
```

#### Django and Gunicorn
For this type of experiment, it is probably best to run Django as you would in production, using a WSGI HTTP server such as Gunicorn. Whilst Django's built in runserver is by default multithreaded, it seems prudent to keep the system close to that of a production system.


### Benchmark

As described above, I have decided to have the withdrawl endpoint as an POST request. This means that I need to get CSRF tokens and session ids before using Ab. These commands are all contained in the script `splatter.sh`.


#### Cookies 
First we GET the login page and save the cookies to a file:

```
curl -c cookies.txt -XGET http://localhost:8001/auth/login/ 2>&1               
```

Then grab the CSRF token from the cookies as so
```
CSRF=$(cat cookies.txt | grep csrftoken | awk -F" " '{print $7}')              
```

Using the token we can login saving a new cookies file, which now includes the sessionid:
```                                                
curl -i --cookie cookies.txt -H "X-CSRFToken:"$CSRF"" -H"Content-Type: application/x-www-form-urlencoded" -X POST -d "username=$UNAME" -d "password=$PWORD" http://localhost:8001/auth/login/ -c new_cookies.txt
```                                                                             
As with the CSRF token we can grab the sessionid:
```
SESSION=$(cat new_cookies.txt | grep session | awk -F" " '{print $7}')         
```


#### Benchmark
Now done to the serious business of using Ab to make a number of concurrent requests. This will make a total of 100 requests (`-n 100`) with 3 concurrent requests (`-c 3`). Note that I had to combine my cookies together separated with a semicolon. 
```
ab -n 100 -c 3 -C "sessionid=$SESSION;csrftoken=$CSRF" -H "X-CSRFToken:$CSRF" -T"Content-Type: application/json" -mPOST http://localhost:8001/accounts/withdraw/
```

What does this tell us? First, we have created 100 transactions (`Transaction.objects.count()`). Second, the current value on the Account model is only 999953 where as you'd hope after 100 withdrawls of value 1 you'd be at 999900. We can count the number of single transactions by grouping the transactions by balance and aggregating, as follows: 
```python
Transaction.objects.values("balance").annotate(count=Count("id")).aggregate(Count("count")) 
```
which evaluates, in this case, to 47. No suprises there.

### Finally ...
So there we have it. We can use Apache Bench to make a number of concurrent HTTP requests and observe it's effect on out application. 



