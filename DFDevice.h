/*
 * Copyright (C) 2011 Matthew Arsenault <arsenm2@rpi.edu>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

#import <Foundation/Foundation.h>
#import <OpenCL/OpenCL.h>

@interface DFDevice : NSObject
{
    NSString* name;
    cl_device_type type;
    BOOL doubles;
}

@property (nonatomic,copy) NSString* name;
@property (nonatomic,assign) cl_device_type type;
@property (nonatomic,assign) BOOL doubles;

- (id) initWithName:(NSString*)inName type:(cl_device_type)inType hasDoubles:(BOOL)inDoubles;

@end
