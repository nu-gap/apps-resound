/** errorHandler.m
Copyright (c) 1998 Jerome Genest.  All rights reserved.
jgenest@gel.ulaval.ca

Permission to use, copy, modify, and distribute this material for any
NON-PROFIT purpose is hereby granted. Commercial use of this material
is granted only with the sole permission of Jerome Genest. Both are
provided that this permission notice appear in all source copies, and that
the author's name shall not be used in advertising or publicity pertaining
to this material without the specific, prior written permission of the author.

THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "ErrorHandler.h"
#import "ResoundNibs.h"


static id defaultHandler;
static BOOL firstObjectAllocated = NO;

@implementation ErrorHandler


+defaultHandler
{
return defaultHandler;
}



-init
{
id returnVal = [super init];
[ResoundNibs loadNibNamed: @"error" owner:self];
hasError = NO;

return returnVal;
}

-(void) awakeFromNib
{
if(firstObjectAllocated == NO)				// should this be in init ?
	{
	defaultHandler = self;
	firstObjectAllocated = YES;
	}

[errorWindow setFloatingPanel:YES];
}

-(void)appendToError:(NSString*)theString
{
[errorText setString:[[errorText string] stringByAppendingString:theString]];
//printf([theString cString]);
hasError = YES;
}

-(void)clearError
{
[errorText setString:@""];
hasError = NO;
}

-(void)showWindowIfNeeded
{
if(hasError)
	[errorWindow makeKeyAndOrderFront:self];
} 

@end
