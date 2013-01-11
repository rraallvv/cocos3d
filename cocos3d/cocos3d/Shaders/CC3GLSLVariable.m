/*
 * CC3GLSLVariable.m
 *
 * cocos3d 2.0.0
 * Author: Bill Hollings
 * Copyright (c) 2011-2013 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * http://en.wikipedia.org/wiki/MIT_License
 * 
 * See header file CC3GLSLVariable.h for full API documentation.
 */

#import "CC3GLSLVariable.h"
#import "CC3GLProgram.h"
#import "CC3OpenGLESVertexArrays.h"


#pragma mark -
#pragma mark CC3GLSLVariable

@implementation CC3GLSLVariable

@synthesize program=_program, index=_index, location=_location, name=_name;
@synthesize type=_type, size=_size, semantic=_semantic, semanticIndex=_semanticIndex;

-(void) dealloc {
	_program = nil;			// not retained
	[_name release];
	[super dealloc];
}


#pragma mark Allocation and initialization

-(id) initInProgram: (CC3GLProgram*) program atIndex: (GLuint) index {
	if ( (self = [super init]) ) {
		_program = program;			// not retained
		_index = index;
		_semantic = kCC3SemanticNone;
		_semanticIndex = 0;
	}
	return self;
}

+(id) variableInProgram: (CC3GLProgram*) program atIndex: (GLuint) index {
	return [[[self alloc] initInProgram: program atIndex: index] autorelease];
}

-(id) copyWithZone: (NSZone*) zone { return [self copyWithZone: zone asClass: self.class]; }

-(id) copyAsClass: (Class) aClass { return [self copyWithZone: nil asClass: aClass]; }

-(id) copyWithZone: (NSZone*) zone asClass: (Class) aClass {
	CC3GLSLVariable* aCopy = [[aClass allocWithZone: zone] initInProgram: _program atIndex: _index];
	[aCopy populateFrom: self];
	return aCopy;
}

-(void) populateFrom: (CC3GLSLVariable*) another {
	// _program & _index set during init
	[_name release];
	_name = [another.name retain];

	_location = another.location;
	_type = another.type;
	_size = another.size;
	_semantic = another.semantic;
	_semanticIndex = another.semanticIndex;
}

-(void) populateFromProgram {}

-(NSString*) description { return [NSString stringWithFormat: @"%@ named %@", self.class, _name]; }

-(NSString*) fullDescription {
	NSMutableString* desc = [NSMutableString stringWithCapacity: 200];
	[desc appendFormat: @"%@", self.description];
	[desc appendFormat: @"\n\t\tLocation: %i", _location];
	[desc appendFormat: @"\n\t\tIndex: %u", _index];
	[desc appendFormat: @"\n\t\tType: %@", NSStringFromGLEnum(_type)];
	[desc appendFormat: @"\n\t\tSize: %i", _size];
	[desc appendFormat: @"\n\t\tSemantic: %@ (%u)", self.semanticName, _semantic];
	[desc appendFormat: @"\n\t\tSemantic index: %u", _semanticIndex];
	return desc;
}

-(NSString*) semanticName { return [_program.semanticDelegate nameOfSemantic: _semantic]; }

@end


#pragma mark -
#pragma mark CC3GLSLAttribute

@implementation CC3GLSLAttribute
@end


#pragma mark -
#pragma mark CC3GLSLUniform

@implementation CC3GLSLUniform

-(void) dealloc {
	free(_varValue);
	[super dealloc];
}

// Protected property for copying
-(GLvoid*) varValue { return _varValue; }

#pragma mark Allocation and initialization

-(id) initInProgram: (CC3GLProgram*) program atIndex: (GLuint) index {
	if ( (self = [super initInProgram: program atIndex: index]) ) {
		_varLen = 0;
		_varValue = NULL;
	}
	return self;
}

-(void) populateFrom: (CC3GLSLUniform*) another {
	[super populateFrom: another];
	_varLen = CC3GLElementTypeSize(_type) * _size;
	free(_varValue);
	_varValue = calloc(_varLen, 1);
}


#pragma mark Accessing uniform values

-(void) setFloat: (GLfloat) value { [self setFloat: value at: 0]; }

-(void) setFloat: (GLfloat) value at: (GLuint) index {
	[self setVector4: CC3Vector4Make(value, 0.0, 0.0, 1.0) at: index];
}

-(void) setPoint: (CGPoint) value { [self setPoint: value at: 0]; }

-(void) setPoint: (CGPoint) value at: (GLuint) index {
	[self setVector4: CC3Vector4Make(value.x, value.y, 0.0, 1.0) at: index];
}

-(void) setVector: (CC3Vector) value { [self setVector: value at: 0]; }

-(void) setVector: (CC3Vector) value at: (GLuint) index {
	[self setVector4: CC3Vector4Make(value.x, value.y, value.z, 1.0) at: index];
}

-(void) setVector4: (CC3Vector4) value { [self setVector4: value at: 0]; }

-(void) setVector4: (CC3Vector4) value at: (GLuint) index {
	NSAssert2(index < _size, @"%@ could not set value because index %u is out of bounds", self, index);
	
	switch (_type) {
			
		case GL_FLOAT:
			((GLfloat*)_varValue)[index] = *(GLfloat*)&value;
			return;
		case GL_FLOAT_VEC2:
			((CGPoint*)_varValue)[index] = *(CGPoint*)&value;
			return;
		case GL_FLOAT_VEC3:
			((CC3Vector*)_varValue)[index] = *(CC3Vector*)&value;
			return;
		case GL_FLOAT_VEC4:
			((CC3Vector4*)_varValue)[index] = value;
			return;
			
		case GL_FLOAT_MAT2:
		case GL_FLOAT_MAT3:
		case GL_FLOAT_MAT4:
			NSAssert(NO, @"%@ attempted to set scalar or vector when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;
			
		case GL_INT:
		case GL_INT_VEC2:
		case GL_INT_VEC3:
		case GL_INT_VEC4:
		case GL_SAMPLER_2D:
		case GL_SAMPLER_CUBE:
		case GL_BOOL:
		case GL_BOOL_VEC2:
		case GL_BOOL_VEC3:
		case GL_BOOL_VEC4:
			[self setIntVector4: CC3IntVector4Make(value.x, value.y, value.z, value.w) at: index];
			return;
			
		default:
			NSAssert2(NO, @"%@ could not set value because type %@ is not understood",
					  self, NSStringFromGLEnum(_type));
			return;
	}
	LogDebug(@"%@ setting value to %@", self.fullDescription, NSStringFromCC3Vector4( value));
}

-(void) setQuaternion: (CC3Quaternion) value { [self setQuaternion: value at: 0]; }

-(void) setQuaternion: (CC3Quaternion) value at: (GLuint) index { [self setVector4: value at: index]; }

-(void) setMatrix3x3: (CC3Matrix3x3*) value { [self setMatrix3x3: value at: 0]; }

-(void) setMatrix3x3: (CC3Matrix3x3*) value at: (GLuint) index {
	switch (_type) {
		case GL_FLOAT_MAT3:
			((CC3Matrix3x3*)_varValue)[index] = *value;
			return;
		default:
			NSAssert(NO, @"%@ attempted to set 3x3 matrix when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;
	}
}

-(void) setMatrix4x4: (CC3Matrix4x4*) value { [self setMatrix4x4: value at: 0]; }

-(void) setMatrix4x4: (CC3Matrix4x4*) value at: (GLuint) index {
	switch (_type) {
		case GL_FLOAT_MAT4:
			((CC3Matrix4x4*)_varValue)[index] = *value;
			return;
		default:
			NSAssert(NO, @"%@ attempted to set 4x4 matrix when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;
	}
}

-(void) setInteger: (GLint) value { [self setInteger: value at: 0]; }

-(void) setInteger: (GLint) value at: (GLuint) index {
	[self setIntVector4: CC3IntVector4Make(value, 0, 0, 0) at: index];
}

-(void) setIntPoint: (CC3IntPoint) value { [self setIntPoint: value at: 0]; }

-(void) setIntPoint: (CC3IntPoint) value at: (GLuint) index {
	[self setIntVector4: CC3IntVector4Make(value.x, value.y, 0, 0) at: index];
}

-(void) setIntVector: (CC3IntVector) value { [self setIntVector: value at: 0]; }

-(void) setIntVector: (CC3IntVector) value at: (GLuint) index {
	[self setIntVector4: CC3IntVector4Make(value.x, value.y, value.z, 0) at: index];
}

-(void) setIntVector4: (CC3IntVector4) value { [self setIntVector4: value at: 0]; }

-(void) setIntVector4: (CC3IntVector4) value at: (GLuint) index {
	NSAssert2(index < _size, @"%@ could not set value because index %u is out of bounds", self, index);
	
	switch (_type) {
			
		case GL_FLOAT:
		case GL_FLOAT_VEC2:
		case GL_FLOAT_VEC3:
		case GL_FLOAT_VEC4:
			[self setVector4: CC3Vector4Make(value.x, value.y, value.z, value.w) at: index];
			return;
			
		case GL_FLOAT_MAT2:
		case GL_FLOAT_MAT3:
		case GL_FLOAT_MAT4:
			NSAssert(NO, @"%@ attempted to set scalar or vector when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;
			
		case GL_INT:
		case GL_BOOL:
		case GL_SAMPLER_2D:
		case GL_SAMPLER_CUBE:
			((GLint*)_varValue)[index] = *(GLint*)&value;
			return;
		case GL_INT_VEC2:
		case GL_BOOL_VEC2:
			((CC3IntPoint*)_varValue)[index] = *(CC3IntPoint*)&value;
			return;
		case GL_INT_VEC3:
		case GL_BOOL_VEC3:
			((CC3IntVector*)_varValue)[index] = *(CC3IntVector*)&value;
			return;
		case GL_INT_VEC4:
		case GL_BOOL_VEC4:
			((CC3IntVector4*)_varValue)[index] = value;
			return;
			
		default:
			NSAssert2(NO, @"%@ could not set value because type %@ is not understood",
					  self, NSStringFromGLEnum(_type));
			return;
	}
	LogDebug(@"%@ setting value to (%i, %i, %i, %i)", self.fullDescription, value.x, value.y, value.z, value.w);
}

-(void) setBoolean: (BOOL) value { [self setBoolean: value at: 0]; }

-(void) setBoolean: (BOOL) value at: (GLuint) index { [self setInteger: value at: index]; }

-(void) setColor: (ccColor3B) value { [self setColor: value at: 0]; }

-(void) setColor: (ccColor3B) value at: (GLuint) index {
	[self setColor4B: ccc4(value.r, value.g, value.b, 255) at: index];
}

-(void) setColor4B: (ccColor4B) value { [self setColor4B: value at: 0]; }

-(void) setColor4B: (ccColor4B) value at: (GLuint) index {
	switch (_type) {

		case GL_FLOAT:
		case GL_FLOAT_VEC2:
		case GL_FLOAT_VEC3:
		case GL_FLOAT_VEC4:
			[self setColor4F: CCC4FFromCCC4B(value)];
			return;
			
		case GL_FLOAT_MAT2:
		case GL_FLOAT_MAT3:
		case GL_FLOAT_MAT4:
			NSAssert(NO, @"%@ attempted to set color when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;

		case GL_INT:
		case GL_BOOL:
		case GL_INT_VEC2:
		case GL_BOOL_VEC2:
		case GL_INT_VEC3:
		case GL_BOOL_VEC3:
		case GL_INT_VEC4:
		case GL_BOOL_VEC4:
		case GL_SAMPLER_2D:
		case GL_SAMPLER_CUBE:
			[self setIntVector4: CC3IntVector4Make(value.r, value.g, value.b, value.a) at: index];
			return;
			
		default:
			NSAssert2(NO, @"%@ could not set value because type %@ is not understood",
					  self, NSStringFromGLEnum(_type));
			return;
	}
}

-(void) setColor4F: (ccColor4F) value { [self setColor4F: value at: 0]; }

-(void) setColor4F: (ccColor4F) value at: (GLuint) index {
	switch (_type) {
			
		case GL_FLOAT:
		case GL_FLOAT_VEC2:
		case GL_FLOAT_VEC3:
		case GL_FLOAT_VEC4:
			[self setVector4: CC3Vector4Make(value.r, value.g, value.b, value.a) at: index];
			return;

		case GL_FLOAT_MAT2:
		case GL_FLOAT_MAT3:
		case GL_FLOAT_MAT4:
			NSAssert(NO, @"%@ attempted to set color when matrix type %@ expected.",
					 self, NSStringFromGLEnum(_type));
			return;

		case GL_INT:
		case GL_BOOL:
		case GL_INT_VEC2:
		case GL_BOOL_VEC2:
		case GL_INT_VEC3:
		case GL_BOOL_VEC3:
		case GL_INT_VEC4:
		case GL_BOOL_VEC4:
		case GL_SAMPLER_2D:
		case GL_SAMPLER_CUBE:
			[self setColor4B: CCC4BFromCCC4F(value)];
			return;

		default:
			NSAssert2(NO, @"%@ could not set value because type %@ is not understood",
					  self, NSStringFromGLEnum(_type));
			return;
	}
}

-(void) setValueFromUniform: (CC3GLSLUniform*) uniform {
	NSAssert2(_type == uniform.type, @"Cannot update %@ from %@ because uniforms are not of the same type",
			  uniform.fullDescription, self.fullDescription);
	NSAssert2(_size == uniform.size, @"Cannot update %@ from %@ because uniforms are not of the same size",
			  uniform.fullDescription, self.fullDescription);
	memcpy(_varValue, uniform.varValue, _varLen);
}

-(BOOL) updateGLValue { return NO; }

@end


#pragma mark -
#pragma mark CC3OpenGLESStateTrackerGLSLAttribute

@implementation CC3OpenGLESStateTrackerGLSLAttribute


#pragma mark Allocation and initialization

-(id) initInProgram: (CC3GLProgram*) program atIndex: (GLuint) index {
	if ( (self = [super initInProgram: program atIndex: index]) ) {
		[self populateFromProgram];
	}
	return self;
}

#if CC3_OGLES_2

-(void) populateFromProgram {
	_semantic = kCC3SemanticNone;
	
	GLint maxNameLen = [_program maxAttributeNameLength];
	char* cName = calloc(maxNameLen, sizeof(char));
	
	glGetActiveAttrib(_program.program, _index, maxNameLen, NULL, &_size, &_type, cName);
	LogGLErrorTrace(@"while retrieving spec for attribute at index %i in %@", _index, self);
	
	_location = glGetAttribLocation(_program.program, cName);
	LogGLErrorTrace(@"while retrieving location of attribute named %s at index %i in %@", cName, _index, self);
	
	[_name release];
	_name = [[NSString stringWithUTF8String: cName] retain];	// retained
	free(cName);
}

#endif

#if CC3_OGLES_1

-(void) populateFromProgram {}

#endif

@end


#pragma mark -
#pragma mark CC3OpenGLESStateTrackerGLSLUniform

@implementation CC3OpenGLESStateTrackerGLSLUniform

-(void) dealloc {
	free(_glVarValue);
	[super dealloc];
}

-(id) initInProgram: (CC3GLProgram*) program atIndex: (GLuint) index {
	if ( (self = [super initInProgram: program atIndex: index]) ) {
		[self populateFromProgram];
	}
	return self;
}

-(void) populateFrom: (CC3OpenGLESStateTrackerGLSLUniform*) another {
	[super populateFrom: another];
	free(_glVarValue);
	_glVarValue = calloc(_varLen, 1);
}


#if CC3_OGLES_2

-(void) populateFromProgram {
	_semantic = 0;
	_semanticIndex = 0;
	
	GLint maxNameLen = [_program maxUniformNameLength];
	char* cName = calloc(maxNameLen, sizeof(char));
	
	glGetActiveUniform(_program.program, _index, maxNameLen, NULL, &_size, &_type, cName);
	LogGLErrorTrace(@"while retrieving spec for active uniform at index %i in %@", _index, self);
	
	_varLen = CC3GLElementTypeSize(_type) * _size;
	free(_varValue);
	_varValue = calloc(_varLen, 1);
	free(_glVarValue);
	_glVarValue = calloc(_varLen, 1);
	
	_location = glGetUniformLocation(_program.program, cName);
	LogGLErrorTrace(@"while retrieving location of active uniform named %s at index %i in %@", cName, _index, self);
	
	[_name release];
	_name = [[NSString stringWithUTF8String: cName] retain];	// retained
	free(cName);
	
	LogDebug(@"%@ populated varValue: %p, glVarValue: %p", self, _varValue, _glVarValue);
}

/** Overridden to update the GL state engine if the value was changed. */
-(BOOL) updateGLValue {
	if (memcmp(_glVarValue, _varValue, _varLen) != 0) {
		memcpy(_glVarValue, _varValue, _varLen);
		[self setGLValue];
		return YES;
	}
	return NO;
}

-(void) setGLValue {
	switch (_type) {
			
		case GL_FLOAT:
			glUniform1fv(_location, _size, _glVarValue);
			return;
		case GL_FLOAT_VEC2:
			glUniform2fv(_location, _size, _glVarValue);
			return;
		case GL_FLOAT_VEC3:
			glUniform3fv(_location, _size, _glVarValue);
			return;
		case GL_FLOAT_VEC4:
			glUniform4fv(_location, _size, _glVarValue);
			return;
			
		case GL_FLOAT_MAT2:
			glUniformMatrix2fv(_location, _size, GL_FALSE, _glVarValue);
			return;
		case GL_FLOAT_MAT3:
			glUniformMatrix3fv(_location, _size, GL_FALSE, _glVarValue);
			return;
		case GL_FLOAT_MAT4:
			glUniformMatrix4fv(_location, _size, GL_FALSE, _glVarValue);
			return;

		case GL_INT:
		case GL_SAMPLER_2D:
		case GL_SAMPLER_CUBE:
		case GL_BOOL:
			glUniform1iv(_location, _size, _glVarValue);
			return;
		case GL_INT_VEC2:
		case GL_BOOL_VEC2:
			glUniform2iv(_location, _size, _glVarValue);
			return;
		case GL_INT_VEC3:
		case GL_BOOL_VEC3:
			glUniform3iv(_location, _size, _glVarValue);
			return;
		case GL_INT_VEC4:
		case GL_BOOL_VEC4:
			glUniform4iv(_location, _size, _glVarValue);
			return;
			
		default:
			NSAssert2(NO, @"%@ could not set GL engine state value because type %@ is not understood",
					  self, NSStringFromGLEnum(_type));
			return;
	}
	LogGLErrorTrace(@"while setting the GL value of %@", self);
}

#endif


#if CC3_OGLES_1

-(void) populateFromProgram {}

#endif

@end

