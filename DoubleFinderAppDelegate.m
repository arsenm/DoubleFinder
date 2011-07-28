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

#import "DoubleFinderAppDelegate.h"
#import "DFDevice.h"

@implementation DoubleFinderAppDelegate

@synthesize window;

static NSString* deviceName(cl_device_id dev)
{
    cl_int err;
    char name[256];
    size_t readSize;

    err = clGetDeviceInfo(dev, CL_DEVICE_NAME, sizeof(name), name, &readSize);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get device extensions" format:@"err = %d", err];
    }

    return [[[NSString alloc] initWithUTF8String:name] copy];
}

static cl_device_type deviceType(cl_device_id dev)
{
    cl_int err;
    cl_device_type type;

    err = clGetDeviceInfo(dev, CL_DEVICE_TYPE, sizeof(type), &type, NULL);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get device type" format:@"err = %d", err];
    }

    return type;
}

static cl_bool deviceHasDoubles(cl_device_id dev)
{
    char exts[4096];
    size_t readSize;
    cl_int err;
    char* khr_fp64;

    // CL_DEVICE_DOUBLE_FP_CONFIG
    // I'm not sure what this does if there is no double extension
    // is it 0? Or what

    err = clGetDeviceInfo(dev, CL_DEVICE_EXTENSIONS, sizeof(exts), exts, &readSize);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get device extensions" format:@"err = %d", err];
    }

    if (readSize >= sizeof(exts))
    {
        [NSException raise:@"Extensions too large" format:@"Read size = %zu", readSize];
    }

    khr_fp64 = strnstr(exts, "cl_khr_fp64", sizeof(exts));

    return (khr_fp64 != NULL);
}

static cl_device_id* getDeviceIds(cl_uint* nDevOut)
{
    cl_platform_id platform;
    cl_uint nPlat, nDev;
    cl_int err;
    cl_device_id* devs;

    err = clGetPlatformIDs(0, NULL, &nPlat);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get platform IDs" format:@"err = %d", err];
    }

    if (nPlat == 0)
    {
        [NSException raise:@"No platforms found" format:@"nPlat = %d", nPlat];
    }

    clGetPlatformIDs(1, &platform, NULL);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get platform ID" format:@"err = %d", err];
    }

    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, 0, NULL, &nDev);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get device ID count" format:@"err = %d", err];
    }

    if (nDev == 0)
    {
        [NSException raise:@"No devices found" format:@"nPlat = %d", nDev];
    }

    devs = malloc(nDev * sizeof(cl_device_id));
    if (!devs)
    {
        perror("Allocating device ids");
        exit(EXIT_FAILURE);
    }

    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, nDev, devs, NULL);
    if (err != CL_SUCCESS)
    {
        [NSException raise:@"Failed to get device IDs" format:@"err = %d", err];
    }

    if (nDevOut)
    {
        *nDevOut = nDev;
    }

    return devs;
}

- (id)init
{
    self = [super init];

    if (self)
    {
        noDoublesString = cpuString = doublesString = mysteryDoublesString = nil;

        devices = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void) applicationDidFinishLaunching:(NSNotification*) aNotification
{
    cl_uint i, nDevices;

    cl_device_id* device_ids = getDeviceIds(&nDevices);

    for (i = 0; i < nDevices; ++i)
    {
        DFDevice * device_obj = [[DFDevice alloc] initWithName:deviceName(device_ids[i])
                                                          type:deviceType(device_ids[i])
                                                    hasDoubles:deviceHasDoubles(device_ids[i])];

        [devices addObject:device_obj];
    }

    [tableView reloadData];
}

- (NSInteger) numberOfRowsInTableView:(NSTableView*) aTableView
{
    return [devices count];
}

- (id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*) column row:(NSInteger)rowIndex
{
    DFDevice * device;

    if(noDoublesString == nil)
    {
        static NSDictionary* redAttribute, * greenAttribute, * orangeAttribute;
        redAttribute = [NSDictionary dictionaryWithObject:[NSColor redColor]
                                                   forKey:NSForegroundColorAttributeName];
        greenAttribute = [NSDictionary dictionaryWithObject:[NSColor greenColor]
                                                     forKey:NSForegroundColorAttributeName];
        orangeAttribute = [NSDictionary dictionaryWithObject:[NSColor orangeColor]
                                                      forKey:NSForegroundColorAttributeName];

        noDoublesString = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTable(@"NO DOUBLES", @"Localizable", @"Device does not have doubles") attributes:redAttribute];
        cpuString = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTable(@"Doubles, but a CPU so not interesting", @"Localizable", @"Device is a CPU and has doubles") attributes:orangeAttribute];
        doublesString = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTable(@"A quality device with a nonbroken OpenCL", @"Localizable", @"Device is a GPU or Accelerator and has doubles") attributes:greenAttribute];
        mysteryDoublesString = [[NSAttributedString alloc] initWithString:NSLocalizedStringFromTable(@"A MYSTERY device with a nonbroken OpenCL", @"Localizable", @"Device is of unknown type and has doubles") attributes:orangeAttribute];
    }

    if (rowIndex >= [devices count])
        return nil;

    device = [devices objectAtIndex:rowIndex];

    if ([[column identifier] isEqualToString:@"DeviceColumn"])
    {
        return device.name;
    }
    else if ([[column identifier] isEqualToString:@"DoubleColumn"])
    {
        if (!device.doubles)
        {
            return noDoublesString;
        }

        switch (device.type)
        {
            case CL_DEVICE_TYPE_CPU:
                return cpuString;
            case CL_DEVICE_TYPE_ACCELERATOR:
            case CL_DEVICE_TYPE_GPU:
                return doublesString;
            default:
                return mysteryDoublesString;
        }
    }

    return nil;
}

@end


